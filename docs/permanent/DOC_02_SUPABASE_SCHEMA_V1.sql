-- DOC_02 - SUPABASE SCHEMA V1.0 - 3 LAYER CONFIG
-- Prioritas 1: Jalankan di Supabase SQL Editor, harus sukses tanpa error baru lanjut

-- 1. Tabel tenants (Layer 2)
create table if not exists tenants (
  tenant_id text primary key,
  toko_name text not null,
  alamat text,
  paket text not null default 'basic' check (paket in ('basic','pro','enterprise')),
  package_id text not null default 'com.btp.uat',
  features jsonb not null default '{"pos": true, "akuntansi": false}'::jsonb,
  max_user int not null default 1,
  expiry date,
  is_blocked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Tabel devices (Layer 3)
create table if not exists devices (
  device_id text primary key,
  tenant_id text not null references tenants(tenant_id) on delete cascade,
  toko_name text,
  package_id text not null default 'com.btp.uat',
  hardware_mode text not null default 'SIMULATED' check (hardware_mode in ('SIMULATED','REAL')),
  printer_type text,
  drawer_mode text,
  last_seen_at timestamptz,
  app_version text default 'a19cb3f',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Tabel licences (tetap, tapi link ke tenants)
create table if not exists licences (
  device_id text primary key references devices(device_id) on delete cascade,
  tenant_id text not null references tenants(tenant_id) on delete cascade,
  toko_name text not null,
  package_id text not null,
  expiry_date date,
  max_user int not null default 1,
  is_blocked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4. Tabel app_config (Layer 1,2,3 semua di sini - KEY PRIMARY KEY, VALUE JSONB)
create table if not exists app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);
-- Contoh keys yang akan ada:
-- 'global'
-- 'tenant:berkah_sumber'
-- 'tenant:berkah_sumber:service:pos'
-- 'tenant:berkah_sumber:service:akuntansi'
-- 'device:infinix_xos_123'
-- 'tenant:clientA'
-- 'device:clientA_kasir1'

-- 5. Tabel config_history (audit permanen, anti tabrakan)
create table if not exists config_history (
  id bigserial primary key,
  key text not null,
  old_value jsonb,
  new_value jsonb not null,
  changed_by text,
  changed_at timestamptz not null default now(),
  version int not null
);
create index if not exists idx_config_history_key on config_history(key);
create index if not exists idx_config_history_changed_at on config_history(changed_at desc);

-- 6. Seed data awal - MIGRASI dari schema lama
-- Insert tenant default dari yang sudah ada
insert into tenants (tenant_id, toko_name, paket, package_id, max_user, expiry, is_blocked)
values ('berkah_sumber', 'Toko Berkah Sumber', 'pro', 'com.btp.uat', 5, '2026-12-31', false)
on conflict (tenant_id) do nothing;

-- Insert device Infinix yang sudah ada
insert into devices (device_id, tenant_id, toko_name, package_id, hardware_mode, app_version)
values ('infinix_xos_123', 'berkah_sumber', 'Toko Berkah Sumber - Kasir 1', 'com.btp.uat', 'SIMULATED', 'a19cb3f')
on conflict (device_id) do nothing;

-- Insert licences untuk device tersebut
insert into licences (device_id, tenant_id, toko_name, package_id, expiry_date, max_user, is_blocked)
values ('infinix_xos_123', 'berkah_sumber', 'Toko Berkah Sumber', 'com.btp.uat', '2026-12-31', 5, false)
on conflict (device_id) do nothing;

-- 7. Seed app_config 3 layer
-- Layer 1 Global
insert into app_config (key, value) values ('global', '{
  "ppn_rate": 11,
  "ppn_account": "2-2010",
  "dpp_account": "4-4010",
  "sales_tunai": "1-1010",
  "sales_qris_pending": "1-1020",
  "sales_transfer": "1-1030",
  "selisih_plus": "4-4040",
  "selisih_minus": "6-6020",
  "tunai_enabled": true,
  "qris_enabled": true,
  "transfer_enabled": true,
  "mdr": 0.7,
  "qris_h1": true,
  "hardware_mode": "SIMULATED",
  "printer_type": "PDF Preview",
  "drawer_mode": "Tunai Only",
  "fefo_enabled": true,
  "fifo_enabled": true,
  "shift_immutable": true,
  "version": 1
}'::jsonb)
on conflict (key) do nothing;

-- Layer 2 Tenant
insert into app_config (key, value) values ('tenant:berkah_sumber', '{
  "tenant_id": "berkah_sumber",
  "toko_name": "Toko Berkah Sumber",
  "paket": "pro",
  "features": {"pos": true, "akuntansi": true},
  "service_pos": {"tunai_enabled": true, "qris_enabled": true, "transfer_enabled": true, "mdr": 0.7},
  "service_akuntansi": {"auto_jurnal": true},
  "max_user": 5,
  "version": 1
}'::jsonb)
on conflict (key) do nothing;

insert into app_config (key, value) values ('tenant:berkah_sumber:service:pos', '{
  "ppn_rate": 11,
  "tunai_enabled": true,
  "qris_enabled": true,
  "transfer_enabled": true,
  "mdr": 0.7,
  "hardware_mode": "SIMULATED"
}'::jsonb)
on conflict (key) do nothing;

insert into app_config (key, value) values ('tenant:berkah_sumber:service:akuntansi', '{
  "ppn_account": "2-2010",
  "sales_tunai": "1-1010",
  "sales_qris_pending": "1-1020",
  "auto_jurnal": true
}'::jsonb)
on conflict (key) do nothing;

-- Layer 3 Device
insert into app_config (key, value) values ('device:infinix_xos_123', '{
  "device_id": "infinix_xos_123",
  "tenant_id": "berkah_sumber",
  "toko_name": "Toko Berkah Sumber - Kasir 1",
  "package_id": "com.btp.uat",
  "hardware_mode": "SIMULATED",
  "printer_type": "PDF Preview",
  "version": 1
}'::jsonb)
on conflict (key) do nothing;

-- Verifikasi
select 'tenants' as table_name, count(*) from tenants
union all select 'devices', count(*) from devices
union all select 'licences', count(*) from licences
union all select 'app_config', count(*) from app_config;
