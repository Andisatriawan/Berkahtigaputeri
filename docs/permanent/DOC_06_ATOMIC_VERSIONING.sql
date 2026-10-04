-- DOC_06 - ATOMIC APP_CONFIG VERSIONING / FINAL POS
-- Phase 6 canonical compare-and-swap write path.
-- Normal updates MUST call update_app_config_atomic(key, new_value, expected_version).

-- Legacy rows may predate the version contract. Normalize once without reducing
-- any existing positive version.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.app_config
    WHERE jsonb_typeof(value) <> 'object'
  ) THEN
    RAISE EXCEPTION 'app_config.value must be a JSON object before Phase 6 version normalization';
  END IF;
END
$$;

UPDATE public.app_config
SET value = (value - 'version') || jsonb_build_object(
  'version',
  CASE
    WHEN coalesce(value ->> 'version', '') ~ '^[1-9][0-9]*$'
      THEN (value ->> 'version')::integer
    ELSE 1
  END
)
WHERE NOT (coalesce(value ->> 'version', '') ~ '^[1-9][0-9]*$');

CREATE OR REPLACE FUNCTION public.update_app_config_atomic(
  key text,
  new_value jsonb,
  expected_version integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_key text := key;
  v_new_value jsonb := new_value;
  v_expected_version integer := expected_version;
  updated_value jsonb;
  updated_at_value timestamptz;
  current_version integer;
BEGIN
  IF v_key IS NULL OR btrim(v_key) = '' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'key is required';
  END IF;

  IF v_new_value IS NULL OR jsonb_typeof(v_new_value) <> 'object' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'new_value must be a JSON object';
  END IF;

  IF v_expected_version IS NULL OR v_expected_version < 1 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'expected_version must be >= 1';
  END IF;

  UPDATE public.app_config AS cfg
  SET value = (v_new_value - 'version')
        || jsonb_build_object('version', v_expected_version + 1),
      updated_at = now()
  WHERE cfg.key = v_key
    AND coalesce(cfg.value ->> 'version', '') ~ '^[1-9][0-9]*$'
    AND (cfg.value ->> 'version')::integer = v_expected_version
  RETURNING cfg.value, cfg.updated_at
  INTO updated_value, updated_at_value;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'key', v_key,
      'value', updated_value,
      'version', v_expected_version + 1,
      'updated_at', updated_at_value
    );
  END IF;

  SELECT (cfg.value ->> 'version')::integer
  INTO current_version
  FROM public.app_config AS cfg
  WHERE cfg.key = v_key;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0002',
      MESSAGE = format('CONFIG_NOT_FOUND key=%s', v_key);
  END IF;

  RAISE EXCEPTION USING
    ERRCODE = '40001',
    MESSAGE = format(
      'VERSION_CONFLICT key=%s expected=%s actual=%s',
      v_key,
      v_expected_version,
      current_version
    );
END;
$$;

REVOKE ALL ON FUNCTION public.update_app_config_atomic(text, jsonb, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_app_config_atomic(text, jsonb, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.update_app_config_atomic(text, jsonb, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_app_config_atomic(text, jsonb, integer) TO service_role;

COMMENT ON FUNCTION public.update_app_config_atomic(text, jsonb, integer) IS
  'Final Pos Phase 6 CAS update: write only when value.version equals expected_version; stored version is always expected_version + 1.';
