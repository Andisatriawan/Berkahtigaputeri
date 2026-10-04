-- DOC_08 - RPC EFFECTIVE CONFIG P6 / FINAL POS
-- Final Pos inheritance:
-- GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
--
-- PHASE 5 AUTH CONTRACT:
-- - anonymous callers have no EXECUTE privilege;
-- - caller must have a real Supabase Auth session;
-- - p_device must belong to p_tenant in public.devices;
-- - non-admin caller must own that device through devices.user_id = auth.uid();
-- - SECURITY DEFINER is retained only to resolve the five config layers after authorization;
-- - search_path is empty and every relation is schema-qualified.
--
-- Service MDR dari workbook yang bertanda inherited_from_template tidak menimpa MDR template.

create or replace function public.get_effective_config(
  p_tenant text,
  p_device text,
  p_service text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb := '{}'::jsonb;
  tenant_cfg jsonb := '{}'::jsonb;
  template_cfg jsonb := '{}'::jsonb;
  service_cfg jsonb := '{}'::jsonb;
  device_cfg jsonb := '{}'::jsonb;
  global_cfg jsonb := '{}'::jsonb;
  template_id text;
  caller_uid uuid := auth.uid();
  caller_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if caller_uid is null
     or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true' then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.devices d
    where d.device_id = p_device
      and d.tenant_id = p_tenant
  ) then
    raise exception 'device does not belong to tenant' using errcode = '42501';
  end if;

  if caller_email <> 'satria@berkahtigaputeri.com'
     and not exists (
       select 1
       from public.devices d
       where d.device_id = p_device
         and d.tenant_id = p_tenant
         and d.user_id = caller_uid
     ) then
    raise exception 'caller is not authorized for device' using errcode = '42501';
  end if;

  select value into global_cfg
  from public.app_config
  where key = 'global';

  select value into tenant_cfg
  from public.app_config
  where key = 'tenant:' || p_tenant;

  template_id := coalesce(tenant_cfg->>'template_id', tenant_cfg->>'template');

  if template_id is not null and template_id <> '' then
    select value into template_cfg
    from public.app_config
    where key = 'template:' || upper(template_id);
  end if;

  select value into service_cfg
  from public.app_config
  where key = 'tenant:' || p_tenant || ':service:' || p_service;

  if service_cfg ? 'inherited_from_template'
     and nullif(service_cfg->>'inherited_from_template', '') is not null then
    service_cfg := service_cfg
      - 'mdr'
      - 'mdr_pos'
      - 'qris_mdr'
      - 'mdr_%';
  end if;

  select value into device_cfg
  from public.app_config
  where key = 'device:' || p_device;

  result := coalesce(global_cfg, '{}'::jsonb)
    || coalesce(template_cfg, '{}'::jsonb)
    || coalesce(tenant_cfg, '{}'::jsonb)
    || coalesce(service_cfg, '{}'::jsonb)
    || coalesce(device_cfg, '{}'::jsonb);

  return result;
end;
$$;

revoke execute on function public.get_effective_config(text, text, text) from public, anon;
grant execute on function public.get_effective_config(text, text, text) to authenticated;

-- Acceptance examples (run with appropriate JWT role/session):
-- anon: RPC must be denied before function execution.
-- authenticated owner: valid device/tenant/service returns effective JSON.
-- authenticated owner + mismatched tenant/device: must error 42501.
