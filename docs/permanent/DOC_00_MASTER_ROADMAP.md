# BERKAH POS - MASTER ROADMAP DOKUMEN PERMANEN
Repo: berkah-ajb-dev/Berkahtigaputeri
Live Admin: https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/
Branch aktif: feat/simulated-hardware-supabase-admin-a19cb3f
HEAD CORE: a19cb3f CI #315 SUCCESS (jangan diutak-atik)

## Tujuan Akhir SaaS
SaaS POS + Akuntansi untuk banyak clients, masing-masing bisa punya 2 layanan berbeda:
- Layanan 1: POS (kasir, barcode, printer, drawer, QRIS)
- Layanan 2: AKUNTANSI (jurnal otomatis, PPN, akun 1-1010 dst)

## Prinsip Dokumen Permanen
- Setiap dokumen tidak menghapus sebelumnya, hanya menambah
- Semua ada di /docs/permanent/ di repo
- Nomor urut = prioritas eksekusi
- Satu prioritas harus LIVE dan terverifikasi baru lanjut next

## Daftar Prioritas (Eksekusi Tanpa Berhenti)

### PRIORITAS 1 (SEKARANG - HARUS SELESAI HARI INI): Fondasi 3 Layer Config
- DOC_01_3_LAYER_CONFIG.md
- DOC_02_SUPABASE_SCHEMA_V1.sql
- Status: Fondasi database harus live di Supabase sebelum UI baru
- Acceptance: Tabel tenants, devices, app_config (key PRIMARY KEY, value JSONB), licences, config_history ada di Supabase live, bisa di-query

### PRIORITAS 2: Keamanan - RLS + Auth Super Admin
- DOC_03_RLS_AUTH.sql
- Acceptance: Hanya super admin (email kamu) bisa write, anon tidak bisa, admin HTML minta login

### PRIORITAS 3: Super Admin List + Edit (Scale banyak clients)
- DOC_04_ADMIN_ARCHITECTURE.md + btp-admin/clients.html + btp-admin/edit.html
- Acceptance: Buka /btp-admin/ -> list semua clients, search, klik edit -> form 43 fields muncul dengan data tenant tersebut

### PRIORITAS 4: Feature Flag 2 Layanan
- DOC_05_FEATURE_FLAGS.md
- Acceptance: Client A bisa POS saja, Client B POS+Akuntansi, APK com.btp.uat otomatis hide menu sesuai flag

### PRIORITAS 5: Audit & Anti-Tabrakan
- DOC_06_AUDIT_VERSIONING.md
- Acceptance: Setiap save tercatat siapa, kapan, apa yang diubah, ada warning jika 2 admin edit bareng

---
Sekarang eksekusi PRIORITAS 1.
