-- DOC_03_RLS_AUTH_FIXED.sql
-- PHASE 5 corrective migration: anon RPC-only config access.
-- Apply after DOC_03 baseline. Idempotent.

alter table public.tenants enable row level security;
alter table public.devices enable row level security;
alter table public.licences enable row level security;
alter table public.app_config enable row level security;
alter table public.tenant_services enable row level security;

-- No direct anonymous table access.
revoke all on table public.tenants from anon;
revoke all on table public.devices from anon;
revoke all on table public.licences from anon;
revoke all on table public.app_config from anon;
revoke all on table public.tenant_services from anon;

drop policy if exists "anon read tenants" on public.tenants;
drop policy if exists "anon read devices" on public.devices;
drop policy if exists "anon read licences" on public.licences;
drop policy if exists "anon read app_config" on public.app_config;
drop policy if exists "anon read tenant_services" on public.tenant_services;

-- Explicit trusted-role privileges; RLS still scopes authenticated rows.
grant select, insert, update, delete
  on table public.tenants, public.devices, public.licences, public.app_config, public.tenant_services
  to authenticated, service_role;

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

  -- Required for anon, authenticated, and service_role alike.
  if not exists (
    select 1
    from public.devices d
    where d.device_id = p_device
      and d.tenant_id = p_tenant
  ) then
    raise exception 'device does not belong to tenant' using errcode = '42501';
  end if;

  -- Authenticated non-admin callers must also own the device.
  -- anon has auth.uid() IS NULL: valid device_id + tenant pair is its device credential.
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

-- PostgreSQL grants EXECUTE to PUBLIC by default; close that generic path.
revoke execute on function public.get_effective_config(text, text, text) from public;
grant execute on function public.get_effective_config(text, text, text)
  to anon, authenticated, service_role;
