# DOCS PERMANENT - PERSISTENCE UNTUK AI AGENT

Folder ini adalah **single source of truth** untuk semua AI/Agent karena context window ChatGPT terbatas.

Setiap AI baru yang masuk repo HARUS baca folder ini dulu.

## Daftar Dokumen (Akumulasi, Jangan Hapus):

- DOC_00_MASTER_ROADMAP.md - Master roadmap + prioritas eksekusi tanpa berhenti
- DOC_01_3_LAYER_CONFIG.md - Arsitektur 3 layer GLOBAL, TENANT, DEVICE + 2 layanan beda
- DOC_02_SUPABASE_SCHEMA_V1.sql - SQL schema v1.0 siap run di Supabase
- DOC_03_RLS_AUTH.sql - RLS + Auth super admin
- DOC_04_ADMIN_ARCHITECTURE.md - Arsitektur admin SaaS scale banyak clients
- DOC_05_FEATURE_FLAGS.md (akan datang - Prioritas 4)
- DOC_06_AUDIT_VERSIONING.md (akan datang - Prioritas 5)

## Cara Pakai:

1. Buka DOC_00 dulu - lihat prioritas mana yang belum LIVE
2. Kerjakan prioritas itu sampai LIVE (screenshot verifikasi)
3. Baru lanjut prioritas next
4. Jangan kerjakan semua sekaligus

## Live URL:

https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/

## Schema Penting:

app_config(key PRIMARY KEY, value JSONB, updated_at)
- key='global'
- key='tenant:<tenant_id>'
- key='tenant:<tenant_id>:service:pos'
- key='tenant:<tenant_id>:service:akuntansi'
- key='device:<device_id>'

Inheritance: GLOBAL -> TENANT -> DEVICE
