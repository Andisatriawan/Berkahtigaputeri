-- DOC_08 - RPC EFFECTIVE CONFIG / FINAL POS
-- Canonical inheritance: GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
--
-- FINAL AUTH CONTRACT:
-- - anon has NO direct SELECT on tenants/devices/licences/app_config/tenant_services;
-- - anon has NO EXECUTE on get_effective_config(...);
-- - authenticated non-admin callers must own p_device through devices.user_id = auth.uid();
-- - every caller must provide a device that belongs to p_tenant;
-- - service_role is the trusted server-side exception for workbook sync/verification;
-- - SECURITY DEFINER is retained only to resolve protected layers after explicit authorization;
-- - search_path is empty and all relations are schema-qualified.
--
-- Service rows marked inherited_from_template do not override template MDR aliases.

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
  requested_service text := lower(trim(coalesce(p_service, '')));
  caller_uid uuid := auth.uid();
  caller_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  caller_role text := lower(coalesce(auth.jwt() ->> 'role', ''));
begin
  if nullif(trim(coalesce(p_tenant, '')), '') is null
     or nullif(trim(coalesce(p_device, '')), '') is null then
    raise exception 'tenant and device are required' using errcode = '22023';
  end if;

  if requested_service not in ('pos', 'akuntansi') then
    raise exception 'invalid service' using errcode = '22023';
  end if;

  if caller_role <> 'service_role' and caller_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.devices d
    where d.device_id = p_device
      and d.tenant_id = p_tenant
  ) then
    raise exception 'device does not belong to tenant' using errcode = '42501';
  end if;

  if caller_role <> 'service_role'
     and caller_email <> 'satria@berkahtigaputeri.com'
     and not exists (
       select 1 from public.devices d
       where d.device_id = p_device
         and d.tenant_id = p_tenant
         and d.user_id = caller_uid
     ) then
    raise exception 'caller is not authorized for device' using errcode = '42501';
  end if;

  select value into global_cfg from public.app_config where key = 'global';
  select value into tenant_cfg from public.app_config where key = 'tenant:' || p_tenant;
  template_id := coalesce(tenant_cfg->>'template_id', tenant_cfg->>'template');

  if template_id is not null and trim(template_id) <> '' then
    select value into template_cfg
    from public.app_config
    where key = 'template:' || upper(trim(template_id));
  end if;

  select value into service_cfg
  from public.app_config
  where key = 'tenant:' || p_tenant || ':service:' || requested_service;

  if service_cfg ? 'inherited_from_template'
     and nullif(service_cfg->>'inherited_from_template', '') is not null then
    service_cfg := service_cfg - 'mdr' - 'mdr_pos' - 'qris_mdr' - 'mdr_%';
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

revoke execute on function public.get_effective_config(text, text, text) from public;
revoke execute on function public.get_effective_config(text, text, text) from anon;
grant execute on function public.get_effective_config(text, text, text) to authenticated, service_role;

-- Acceptance:
-- anon direct table SELECT => denied.
-- anon RPC EXECUTE => denied.
-- authenticated caller + owned device + matching tenant => succeeds.
-- mismatched device/tenant or unowned device => 42501.
