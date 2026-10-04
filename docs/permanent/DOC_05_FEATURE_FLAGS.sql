-- DOC_05 FEATURE FLAGS UAT SEED
-- Copy paste ini di Supabase SQL Editor. ChatGPT tidak menjalankan SQL ini langsung.
-- Phase 6: every app_config seed has version=1 on first insert and preserves
-- the existing positive version on conflict.

insert into tenants (tenant_id, toko_name, paket, package_id, features, max_user, is_blocked)
values
  ('clientA', 'Client A POS Only', 'basic', 'com.btp.uat', '{"pos":true,"akuntansi":false}'::jsonb, 1, false),
  ('clientB', 'Client B POS + Akuntansi', 'pro', 'com.btp.uat', '{"pos":true,"akuntansi":true}'::jsonb, 5, false)
on conflict (tenant_id) do update set
  toko_name = excluded.toko_name,
  paket = excluded.paket,
  features = excluded.features,
  max_user = excluded.max_user,
  is_blocked = excluded.is_blocked,
  updated_at = now();

insert into app_config as current_config (key, value, updated_at)
values
  ('tenant:clientA:service:pos', '{"qris_enabled":true,"mdr":0.5,"qris_mdr":0.5,"version":1}'::jsonb, now()),
  ('tenant:clientB:service:pos', '{"qris_enabled":true,"mdr":0.7,"qris_mdr":0.7,"version":1}'::jsonb, now()),
  ('tenant:clientB:service:akuntansi', '{"auto_jurnal":true,"ppn_account":"2-2010","version":1}'::jsonb, now())
on conflict (key) do update set
  value = (current_config.value || (excluded.value - 'version'))
    || jsonb_build_object(
      'version',
      case
        when coalesce(current_config.value ->> 'version', '') ~ '^[1-9][0-9]*$'
          then (current_config.value ->> 'version')::integer
        else 1
      end
    ),
  updated_at = excluded.updated_at;

select tenant_id, features from tenants where tenant_id in ('clientA','clientB') order by tenant_id;
select key, value from app_config where key like 'tenant:clientA:service:%' or key like 'tenant:clientB:service:%' order by key;
