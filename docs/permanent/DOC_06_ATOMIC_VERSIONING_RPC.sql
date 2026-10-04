-- DOC_06 - ATOMIC APP_CONFIG VERSIONING RPC / FINAL POS
-- Canonical Phase 6 write path for public.app_config.
--
-- Runtime/admin writers must use this RPC instead of read-compare-upsert.
-- Workbook import is a versioned administrative replacement and uses the same
-- RPC; --force-version only refreshes a conflicting live version and retries.
--
-- SECURITY NOTE:
-- The function is SECURITY DEFINER because it must perform the atomic write
-- independently of table RLS, but execution is still restricted inside the
-- function to the canonical admin identity or service_role JWT. This preserves
-- the Phase 5 tenant-isolation contract for ordinary authenticated device users.

-- Parameter names are part of the PostgREST RPC contract. The previous Phase 6
-- draft used key/new_value/expected_version, so drop the old signature first to
-- allow the canonical p_* names below. The migration is transactional.
drop function if exists public.update_app_config_atomic(text, jsonb, integer);

create or replace function public.update_app_config_atomic(
  p_key text,
  p_new_value jsonb,
  p_expected_version int
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current jsonb;
  v_current_version int;
  v_new_version int;
  v_role text := coalesce(auth.jwt() ->> 'role', '');
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if v_role <> 'service_role' and v_email <> 'satria@berkahtigaputeri.com' then
    raise exception 'not authorized to update app_config' using errcode = '42501';
  end if;

  if p_key is null or btrim(p_key) = '' then
    raise exception 'key is required' using errcode = '22023';
  end if;

  if p_new_value is null or jsonb_typeof(p_new_value) <> 'object' then
    raise exception 'new value must be a JSON object' using errcode = '22023';
  end if;

  if p_expected_version is null or p_expected_version < 1 then
    raise exception 'expected version must be >= 1' using errcode = '22023';
  end if;

  select value
    into v_current
    from public.app_config
   where key = p_key
   for update;

  if not found then
    raise exception 'key not found %', p_key using errcode = 'P0002';
  end if;

  if coalesce(v_current ->> 'version', '') !~ '^[1-9][0-9]*$' then
    raise exception 'invalid current version for key %', p_key using errcode = '22023';
  end if;

  v_current_version := (v_current ->> 'version')::int;
  if v_current_version != p_expected_version then
    raise exception 'version conflict: expected % got %', p_expected_version, v_current_version
      using errcode = '40001';
  end if;

  v_new_version := p_expected_version + 1;
  p_new_value := jsonb_set(p_new_value, '{version}', to_jsonb(v_new_version), true);

  update public.app_config
     set value = p_new_value,
         updated_at = now()
   where key = p_key
     and (value ->> 'version')::int = p_expected_version;

  if not found then
    raise exception 'concurrent update' using errcode = '40001';
  end if;

  return p_new_value;
end;
$$;

revoke all on function public.update_app_config_atomic(text, jsonb, integer) from public, anon;
grant execute on function public.update_app_config_atomic(text, jsonb, integer) to authenticated, service_role;

comment on function public.update_app_config_atomic(text, jsonb, integer) is
  'Final Pos Phase 6 atomic app_config compare-and-swap. Locks the row, validates expected version, stores expected+1, and returns the stored JSON value.';
