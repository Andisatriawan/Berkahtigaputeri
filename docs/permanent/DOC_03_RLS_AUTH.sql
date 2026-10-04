-- DOC_03 - RLS + AUTH / FINAL POS TENANT ISOLATION
-- FINAL Phase 7 auth contract.
--
-- AUTH MODEL:
-- 1) anon has NO direct SELECT/INSERT/UPDATE/DELETE on tenants/devices/licences/app_config/tenant_services.
-- 2) anon has NO EXECUTE on public.get_effective_config(text,text,text).
-- 3) authenticated runtime users must own the requested device through devices.user_id = auth.uid().
-- 4) every get_effective_config() call validates device_id -> tenant_id before reading config.
-- 5) canonical super admin is authenticated and may manage all Final Pos rows.
-- 6) service_role retains trusted server-side access for workbook sync and verification.
-- 7) all five Final Pos backing tables have RLS enabled.
--
-- Super admin canonical: satria@berkahtigaputeri.com

alter table public.tenants enable row level security;
alter table public.devices enable row level security;
alter table public.licences enable row level security;
alter table public.app_config enable row level security;
alter table public.tenant_services enable row level security;

revoke all on table public.tenants from anon;
revoke all on table public.devices from anon;
revoke all on table public.licences from anon;
revoke all on table public.app_config from anon;
revoke all on table public.tenant_services from anon;

grant select, insert, update, delete
  on table public.tenants, public.devices, public.licences, public.app_config, public.tenant_services
  to authenticated, service_role;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.can_read_final_pos_config(config_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.devices d
      left join public.tenants t on t.tenant_id = d.tenant_id
      where d.user_id = (select auth.uid())
        and (
          config_key = 'global'
          or config_key = 'device:' || d.device_id
          or config_key = 'tenant:' || d.tenant_id
          or left(config_key, length('tenant:' || d.tenant_id || ':service:'))
               = 'tenant:' || d.tenant_id || ':service:'
          or config_key = 'template:' || upper(coalesce(t.template_id, t.paket))
        )
    );
$$;

revoke execute on function private.can_read_final_pos_config(text) from public, anon;
grant execute on function private.can_read_final_pos_config(text) to authenticated;

drop policy if exists "anon read tenants" on public.tenants;
drop policy if exists "anon read devices" on public.devices;
drop policy if exists "anon read licences" on public.licences;
drop policy if exists "anon read app_config" on public.app_config;
drop policy if exists "anon read tenant_services" on public.tenant_services;

drop policy if exists "authenticated read own tenants" on public.tenants;
drop policy if exists "authenticated read own devices" on public.devices;
drop policy if exists "authenticated read own licences" on public.licences;
drop policy if exists "authenticated read own app_config" on public.app_config;
drop policy if exists "authenticated read own tenant_services" on public.tenant_services;

create policy "authenticated read own devices" on public.devices
for select to authenticated using (user_id = (select auth.uid()));

create policy "authenticated read own tenants" on public.tenants
for select to authenticated using (
  exists (
    select 1 from public.devices d
    where d.tenant_id = tenants.tenant_id
      and d.user_id = (select auth.uid())
  )
);

create policy "authenticated read own licences" on public.licences
for select to authenticated using (
  exists (
    select 1 from public.devices d
    where d.device_id = licences.device_id
      and d.tenant_id = licences.tenant_id
      and d.user_id = (select auth.uid())
  )
);

create policy "authenticated read own tenant_services" on public.tenant_services
for select to authenticated using (
  exists (
    select 1 from public.devices d
    where d.tenant_id = tenant_services.tenant_id
      and d.user_id = (select auth.uid())
  )
);

create policy "authenticated read own app_config" on public.app_config
for select to authenticated using (private.can_read_final_pos_config(key));

drop policy if exists "super admin all tenants" on public.tenants;
drop policy if exists "super admin all devices" on public.devices;
drop policy if exists "super admin all licences" on public.licences;
drop policy if exists "super admin all app_config" on public.app_config;
drop policy if exists "super admin all tenant_services" on public.tenant_services;

create policy "super admin all tenants" on public.tenants for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com')
  with check (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com');
create policy "super admin all devices" on public.devices for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com')
  with check (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com');
create policy "super admin all licences" on public.licences for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com')
  with check (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com');
create policy "super admin all app_config" on public.app_config for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com')
  with check (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com');
create policy "super admin all tenant_services" on public.tenant_services for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com')
  with check (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com');

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
    where d.device_id = p_device and d.tenant_id = p_tenant
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
    select value into template_cfg from public.app_config
    where key = 'template:' || upper(trim(template_id));
  end if;
  select value into service_cfg from public.app_config
  where key = 'tenant:' || p_tenant || ':service:' || requested_service;
  if service_cfg ? 'inherited_from_template'
     and nullif(service_cfg->>'inherited_from_template', '') is not null then
    service_cfg := service_cfg - 'mdr' - 'mdr_pos' - 'qris_mdr' - 'mdr_%';
  end if;
  select value into device_cfg from public.app_config where key = 'device:' || p_device;

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
-- anon direct SELECT on backing Final Pos tables => denied.
-- anon EXECUTE get_effective_config => denied.
-- authenticated non-admin RPC => device ownership required.
-- every RPC => device must belong to requested tenant.
-- service_role app_config count => canonical 352.
