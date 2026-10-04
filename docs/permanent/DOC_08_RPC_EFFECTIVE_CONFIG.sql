-- DOC_08 - RPC EFFECTIVE CONFIG / FINAL POS
-- Final Pos inheritance:
-- GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
--
-- PHASE 5 AUTH CONTRACT:
-- - anon has NO direct SELECT privilege on tenants/devices/licences/app_config/tenant_services;
-- - anon MAY execute get_effective_config(p_tenant,p_device,p_service);
-- - every RPC call validates public.devices.device_id belongs to p_tenant;
-- - for anon (auth.uid() is null), knowledge of the valid device_id + tenant pair is the current device credential;
-- - authenticated non-admin callers must additionally own that device through devices.user_id = auth.uid();
-- - service_role may execute the RPC and retains server-side table access;
-- - SECURITY DEFINER is retained only to resolve protected config layers after validation;
-- - search_path is empty and every relation is schema-qualified.
--
-- NOTE: devices currently has no secret column. A future device_secret can replace
-- device-id possession without changing the five-layer merge contract.
--
-- Service MDR from workbook rows marked inherited_from_template does not override template MDR.

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
begin
  if nullif(trim(coalesce(p_tenant, '')), '') is null
     or nullif(trim(coalesce(p_device, '')), '') is null then
    raise exception 'tenant and device are required' using errcode = '22023';
  end if;

  if requested_service not in ('pos', 'akuntansi') then
    raise exception 'invalid service' using errcode = '22023';
  end if;

  -- Mandatory SaaS boundary for every caller, including anon and service_role.
  if not exists (
    select 1
    from public.devices d
    where d.device_id = p_device
      and d.tenant_id = p_tenant
  ) then
    raise exception 'device does not belong to tenant' using errcode = '42501';
  end if;

  -- Signed-in runtime callers retain the stronger user->device ownership check.
  -- anon has caller_uid IS NULL, so the validated device_id + tenant pair is its credential.
  if caller_uid is not null
     and caller_email <> 'satria@berkahtigaputeri.com'
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

-- Functions are executable by PUBLIC by default unless explicitly revoked.
revoke execute on function public.get_effective_config(text, text, text) from public;
grant execute on function public.get_effective_config(text, text, text) to anon, authenticated, service_role;

-- Acceptance:
-- 1) anon direct table SELECT is denied by DOC_03 grants/RLS.
-- 2) anon + valid device/tenant pair can execute this RPC.
-- 3) mismatched device/tenant pair raises 42501 'device does not belong to tenant'.
-- 4) signed-in non-admin caller must additionally own the device.
