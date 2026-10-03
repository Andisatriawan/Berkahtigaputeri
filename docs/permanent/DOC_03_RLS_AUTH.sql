-- DOC_03 - RLS + AUTH SUPER ADMIN
-- Prioritas 2: Jalankan setelah DOC_02 sukses

-- Enable RLS
alter table tenants enable row level security;
alter table devices enable row level security;
alter table licences enable row level security;
alter table app_config enable row level security;
alter table config_history enable row level security;

-- Policy: anon bisa read saja (untuk APK), tidak bisa write
create policy if not exists "anon read tenants" on tenants for select to anon using (true);
create policy if not exists "anon read devices" on devices for select to anon using (true);
create policy if not exists "anon read licences" on licences for select to anon using (true);
create policy if not exists "anon read app_config" on app_config for select to anon using (true);

-- Policy: authenticated super admin bisa all
-- Ganti email di bawah dengan email super admin kamu
create policy if not exists "super admin all tenants" on tenants for all to authenticated using (
  auth.jwt() ->> 'email' = 'satria@berkahtigaputeri.com'
);
create policy if not exists "super admin all devices" on devices for all to authenticated using (
  auth.jwt() ->> 'email' = 'satria@berkahtigaputeri.com'
);
create policy if not exists "super admin all licences" on licences for all to authenticated using (
  auth.jwt() ->> 'email' = 'satria@berkahtigaputeri.com'
);
create policy if not exists "super admin all app_config" on app_config for all to authenticated using (
  auth.jwt() ->> 'email' = 'satria@berkahtigaputeri.com'
);
create policy if not exists "super admin read history" on config_history for select to authenticated using (
  auth.jwt() ->> 'email' = 'satria@berkahtigaputeri.com'
);

-- Function untuk audit otomatis
create or replace function log_config_change() returns trigger as $$
begin
  insert into config_history (key, old_value, new_value, changed_by, version)
  values (
    coalesce(new.key, old.key),
    old.value,
    new.value,
    auth.jwt() ->> 'email',
    coalesce((new.value->>'version')::int, (old.value->>'version')::int, 1)
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_app_config_audit on app_config;
create trigger trg_app_config_audit after insert or update on app_config
for each row execute function log_config_change();
