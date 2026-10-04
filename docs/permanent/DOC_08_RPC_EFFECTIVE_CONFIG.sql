-- DOC_08 - RPC EFFECTIVE CONFIG P6 / FINAL POS
-- Copy paste ini di Supabase SQL Editor dan Run untuk membuat RPC.
-- Final Pos inheritance:
-- GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
-- Service MDR dari workbook yang bertanda inherited_from_template tidak menimpa MDR template.
-- Test canonical 100-tenant seed:
-- SELECT get_effective_config('tenant_001','infinix_001_410','pos');

CREATE OR REPLACE FUNCTION public.get_effective_config(
  p_tenant text,
  p_device text,
  p_service text
) RETURNS jsonb AS $$
DECLARE
  result jsonb := '{}'::jsonb;
  tenant_cfg jsonb := '{}'::jsonb;
  template_cfg jsonb := '{}'::jsonb;
  service_cfg jsonb := '{}'::jsonb;
  device_cfg jsonb := '{}'::jsonb;
  global_cfg jsonb := '{}'::jsonb;
  template_id text;
BEGIN
  SELECT value INTO global_cfg
  FROM public.app_config
  WHERE key = 'global';

  SELECT value INTO tenant_cfg
  FROM public.app_config
  WHERE key = 'tenant:' || p_tenant;

  template_id := COALESCE(tenant_cfg->>'template_id', tenant_cfg->>'template');

  IF template_id IS NOT NULL AND template_id <> '' THEN
    SELECT value INTO template_cfg
    FROM public.app_config
    WHERE key = 'template:' || upper(template_id);
  END IF;

  SELECT value INTO service_cfg
  FROM public.app_config
  WHERE key = 'tenant:' || p_tenant || ':service:' || p_service;

  IF service_cfg ? 'inherited_from_template'
     AND NULLIF(service_cfg->>'inherited_from_template', '') IS NOT NULL THEN
    service_cfg := service_cfg
      - 'mdr'
      - 'mdr_pos'
      - 'qris_mdr'
      - 'mdr_%';
  END IF;

  SELECT value INTO device_cfg
  FROM public.app_config
  WHERE key = 'device:' || p_device;

  result := COALESCE(global_cfg, '{}'::jsonb)
    || COALESCE(template_cfg, '{}'::jsonb)
    || COALESCE(tenant_cfg, '{}'::jsonb)
    || COALESCE(service_cfg, '{}'::jsonb)
    || COALESCE(device_cfg, '{}'::jsonb);

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
