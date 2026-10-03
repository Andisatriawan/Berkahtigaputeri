# DOC_04 - ARSITEKTUR ADMIN SAAS (PERMANEN)

## Struktur Folder di Repo (Akumulasi Permanen)
```
/docs/permanent/
  DOC_00_MASTER_ROADMAP.md
  DOC_01_3_LAYER_CONFIG.md
  DOC_02_SUPABASE_SCHEMA_V1.sql
  DOC_03_RLS_AUTH.sql
  DOC_04_ADMIN_ARCHITECTURE.md
  DOC_05_FEATURE_FLAGS.md
  DOC_06_AUDIT_VERSIONING.md

/btp-admin/
  index.html (redirect ke clients.html)
  clients.html (Super Admin List - Prioritas 3)
  edit.html (Form 43 fields dengan 3 layer - Prioritas 3)
  login.html (Supabase Auth - Prioritas 2)
```

## Flow Banyak Clients Submit Beda 2 Layanan

### Skenario: 10 Clients Submit Bersamaan
1. Client A (Toko A) submit: service_pos.mdr=0.5% (paket pro)
   -> Write key='tenant:clientA:service:pos' saja, tidak ganggu global
2. Client B (Toko B) submit: service_pos.mdr=0.7% (paket basic)
   -> Write key='tenant:clientB:service:pos' saja
3. Tidak ada tabrakan karena key beda

### Skenario: 2 Layanan Beda di 1 Client
Tenant berkah_sumber:
- butuh POS dengan QRIS ON, Transfer OFF
- butuh Akuntansi dengan auto jurnal ON
-> 2 rows:
  tenant:berkah_sumber:service:pos {qris_enabled:true, transfer_enabled:false}
  tenant:berkah_sumber:service:akuntansi {auto_jurnal:true}

APK com.btp.uat baca:
```dart
final posConfig = await supabase.from('app_config').select().eq('key','tenant:berkah_sumber:service:pos').single();
final akConfig = await supabase.from('app_config').select().eq('key','tenant:berkah_sumber:service:akuntansi').single();
if (posConfig['value']['qris_enabled']) showQRIS();
if (akConfig['value']['auto_jurnal']) enableJurnal();
```

## Prioritas Eksekusi Tanpa Berhenti

### PRIORITAS 1: Fondasi (HARI INI)
- [ ] Jalankan DOC_02_SUPABASE_SCHEMA_V1.sql di Supabase SQL Editor
- [ ] Verifikasi 4 tabel ada: tenants, devices, licences, app_config, config_history
- [ ] Cek select * from app_config -> harus ada 5 rows: global, tenant:berkah_sumber, tenant:berkah_sumber:service:pos, tenant:berkah_sumber:service:akuntansi, device:infinix_xos_123
- [ ] Update btp-admin/index.html yang LIVE untuk baca dari 3 layer (bukan 1 layer lama)

### PRIORITAS 2: Keamanan (Besok)
- [ ] Jalankan DOC_03_RLS_AUTH.sql
- [ ] Buat user super admin di Supabase Auth
- [ ] Test anon tidak bisa write, authenticated bisa

### PRIORITAS 3: Scale (Lusa)
- [ ] Buat btp-admin/clients.html
- [ ] Buat btp-admin/edit.html

Setiap prioritas harus LIVE dan screenshot verifikasi baru lanjut.

## Catatan Permanen
- Jangan hapus DOC_00-04, akumulasi
- Semua SQL harus idempotent (if not exists, on conflict do nothing) agar bisa rerun tanpa error
- Version di JSONB harus increment setiap save untuk deteksi tabrakan
