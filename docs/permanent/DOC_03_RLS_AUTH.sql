-- DOC_03 - RLS + AUTH SUPER ADMIN
-- PRIORITAS 2
-- COPY/PASTE SELURUH FILE INI ke Supabase SQL Editor jika perlu rerun manual.
-- Idempotent: policy lama di-drop lalu dibuat ulang sesuai kontrak.
-- Super admin canonical: satria@berkahtigaputeri.com

alter table public.tenants enable row level security;
alter table public.devices enable row level security;
alter table public.licences enable row level security;
alter table public.app_config enable row level security;
alter table public.config_history enable row level security;

-- Grants: anon read only; authenticated mendapat operasi write tetapi tetap dibatasi RLS.
revoke all on table public.tenants from anon, authenticated;
revoke all on table public.devices from anon, authenticated;
revoke all on table public.licences from anon, authenticated;
revoke all on table public.app_config from anon, authenticated;
revoke all on table public.config_history from anon, authenticated;

grant select on table public.tenants, public.devices, public.licences, public.app_config to anon;
grant select, insert, update, delete on table public.tenants, public.devices, public.licences, public.app_config to authenticated;
grant select, insert on table public.config_history to authenticated;

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
drop policy if exists "super admin all tenants" on public.tenants;
drop policy if exists "super admin all devices" on public.devices;
drop policy if exists "super admin all licences" on public.licences;
drop policy if exists "super admin all app_config" on public.app_config;
drop policy if exists "super admin read history" on public.config_history;
drop policy if exists "super admin insert history" on public.config_history;

-- ANON: read saja untuk kebutuhan client/APK.
create policy "anon read tenants" on public.tenants for select to anon using (true);
create policy "anon read devices" on public.devices for select to anon using (true);
create policy "anon read licences" on public.licences for select to anon using (true);
create policy "anon read app_config" on public.app_config for select to anon using (true);

-- AUTHENTICATED SUPER ADMIN: write hanya untuk email canonical.
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

create policy "super admin read history" on public.config_history for select to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com');

create policy "super admin insert history" on public.config_history for insert to authenticated
  with check (lower(coalesce(auth.jwt() ->> 'email','')) = 'satria@berkahtigaputeri.com');

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

-- Acceptance manual setelah rerun:
-- 1) anon UPDATE/INSERT app_config harus gagal.
-- 2) login Supabase Auth sebagai satria@berkahtigaputeri.com lalu write harus berhasil.
