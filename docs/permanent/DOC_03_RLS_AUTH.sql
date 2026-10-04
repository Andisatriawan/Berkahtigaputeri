-- DOC_03 - RLS + AUTH / FINAL POS TENANT ISOLATION
-- PHASE 5 canonical auth contract.
-- COPY/PASTE SELURUH FILE INI ke Supabase SQL Editor jika perlu rerun manual.
-- Idempotent: policy lama di-drop lalu dibuat ulang sesuai kontrak.
--
-- AUTH MODEL:
-- 1) Tidak ada anonymous read untuk tenants/devices/licences/app_config/tenant_services.
-- 2) Client runtime wajib mempunyai Supabase Auth session.
-- 3) Device runtime hanya dapat membaca tenant/device/licence/config yang terikat ke auth.uid().
-- 4) Super admin canonical tetap dapat mengelola seluruh data setelah authenticated.
-- 5) get_effective_config() tetap SECURITY DEFINER karena membaca lintas layer app_config,
--    tetapi EXECUTE untuk anon dicabut, search_path dikosongkan, device wajib milik tenant,
--    dan caller biasa wajib merupakan user yang terikat pada device tersebut.
-- Super admin canonical: satria@berkahtigaputeri.com

alter table public.tenants enable row level security;
alter table public.devices enable row level security;
alter table public.licences enable row level security;
alter table public.app_config enable row level security;
alter table public.config_history enable row level security;
alter table public.tenant_services enable row level security;

-- No Data API privilege for anon on Final Pos config/identity tables.
revoke all on table public.tenants from anon, authenticated;
revoke all on table public.devices from anon, authenticated;
revoke all on table public.licences from anon, authenticated;
revoke all on table public.app_config from anon, authenticated;
revoke all on table public.config_history from anon, authenticated;
revoke all on table public.tenant_services from anon, authenticated;

-- Authenticated gets table privileges, then RLS determines rows.
-- Non-admin authenticated users receive SELECT-only policies below.
grant select, insert, update, delete
  on table public.tenants, public.devices, public.licences, public.app_config, public.tenant_services
  to authenticated;
grant select, insert on table public.config_history to authenticated;

-- Helper lives outside exposed public schema. SECURITY DEFINER is deliberate:
-- it must inspect relational ownership while app_config RLS itself is being evaluated.
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

-- Bersihkan policy legacy / policy dari rerun sebelumnya.
drop policy if exists "app_config_admin_insert" on public.app_config;
drop policy if exists "app_config_admin_select" on public.app_config;
drop policy if exists "app_config_admin_update" on public.app_config;
drop policy if exists "licences_admin_insert" on public.licences;
drop policy if exists "licences_admin_select" on public.licences;
drop policy if exists "licences_admin_update" on public.licences;

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

drop policy if exists "super admin all tenants" on public.tenants;
drop policy if exists "super admin all devices" on public.devices;
drop policy if exists "super admin all licences" on public.licences;
drop policy if exists "super admin all app_config" on public.app_config;
drop policy if exists "super admin all tenant_services" on public.tenant_services;
drop policy if exists "super admin read history" on public.config_history;
drop policy if exists "super admin insert history" on public.config_history;

-- AUTHENTICATED DEVICE USER: tenant isolation is derived from devices.user_id.
create policy "authenticated read own devices" on public.devices
for select to authenticated
using (user_id = (select auth.uid()));

create policy "authenticated read own tenants" on public.tenants
for select to authenticated
using (
  exists (
    select 1
    from public.devices d
    where d.tenant_id = tenants.tenant_id
      and d.user_id = (select auth.uid())
  )
);

create policy "authenticated read own licences" on public.licences
for select to authenticated
using (
  exists (
    select 1
    from public.devices d
    where d.device_id = licences.device_id
      and d.tenant_id = licences.tenant_id
      and d.user_id = (select auth.uid())
  )
);

create policy "authenticated read own tenant_services" on public.tenant_services
for select to authenticated
using (
  exists (
    select 1
    from public.devices d
    where d.tenant_id = tenant_services.tenant_id
      and d.user_id = (select auth.uid())
  )
);

create policy "authenticated read own app_config" on public.app_config
for select to authenticated
using (private.can_read_final_pos_config(key));

-- AUTHENTICATED SUPER ADMIN: full management only for canonical admin email.
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

create policy "super admin read history" on public.config_history for select to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com');

create policy "super admin insert history" on public.config_history for insert to authenticated
  with check (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com');

-- Hardened Final Pos effective-config RPC.
-- Merge order remains GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE.
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

  -- Always validate relational device -> tenant ownership, including super admin.
  if not exists (
    select 1
    from public.devices d
    where d.device_id = p_device
      and d.tenant_id = p_tenant
  ) then
    raise exception 'device does not belong to tenant' using errcode = '42501';
  end if;

  -- Normal authenticated callers must also own the requested device.
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

-- PostgreSQL grants EXECUTE to PUBLIC by default; explicitly close that path.
revoke execute on function public.get_effective_config(text, text, text) from public, anon;
grant execute on function public.get_effective_config(text, text, text) to authenticated;

-- Audit otomatis. SECURITY INVOKER menjaga trigger tetap tunduk pada policy pemanggil.
create or replace function public.log_config_change() returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  insert into public.config_history (key, old_value, new_value, changed_by, version)
  values (
    coalesce(new.key, old.key),
    case when tg_op='INSERT' then null else old.value end,
    new.value,
    auth.jwt() ->> 'email',
    coalesce((new.value->>'version')::int,
             case when tg_op='INSERT' then null else (old.value->>'version')::int end,
             1)
  );
  return new;
end;
$$;

drop trigger if exists trg_app_config_audit on public.app_config;
create trigger trg_app_config_audit
after insert or update on public.app_config
for each row execute function public.log_config_change();

-- Acceptance setelah rerun:
-- 1) anon SELECT tenants/devices/licences/app_config harus gagal.
-- 2) anon EXECUTE get_effective_config(text,text,text) harus gagal.
-- 3) authenticated user hanya melihat device/tenant/licence/config miliknya.
-- 4) RPC dengan device + tenant yang tidak cocok harus error 42501.
-- 5) RPC dengan device milik user lain harus error 42501.
-- 6) super admin authenticated tetap dapat mengelola seluruh data,
--    tetapi RPC tetap mensyaratkan pasangan device -> tenant yang valid.
