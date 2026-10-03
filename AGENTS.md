# AGENTS COMPLIANCE - WAJIB DIBACA SEMUA AI/AGENT

Repo: berkah-ajb-dev/Berkahtigaputeri
Live Admin: https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/
HEAD CORE: a19cb3f CI #315 SUCCESS - JANGAN DIUBAH TANPA IZIN

## ATURAN UTAMA - KAMU HARUS BACA INI DULU SEBELUM KODING

Kamu adalah AI Agent yang baru masuk ke repo ini. Context window kamu terbatas, tapi dokumen di /docs/permanent/ adalah PERMANEN dan WAJIB compliance.

### Urutan Baca Wajib (Jangan skip):
1. /docs/permanent/DOC_00_MASTER_ROADMAP.md - Roadmap prioritas
2. /docs/permanent/DOC_01_3_LAYER_CONFIG.md - Arsitektur 3 layer (GLOBAL, TENANT, DEVICE)
3. /docs/permanent/DOC_02_SUPABASE_SCHEMA_V1.sql - Schema Supabase live
4. /docs/permanent/DOC_03_RLS_AUTH.sql - Keamanan RLS
5. /docs/permanent/DOC_04_ADMIN_ARCHITECTURE.md - Arsitektur admin SaaS

### 3 Layer Config - JANGAN SALAH SCHEMA:
- Layer 1: key='global' -> value JSONB default semua
- Layer 2: key='tenant:<id>' + key='tenant:<id>:service:pos' + key='tenant:<id>:service:akuntansi' -> per client, 2 layanan beda
- Layer 3: key='device:<id>' -> per HP kasir
- Schema live: app_config(key PRIMARY KEY, value JSONB, updated_at) - BUKAN app_config(device_id, key, value) LAMA
- Inheritance: GLOBAL -> TENANT -> DEVICE (merge override)

### Larangan:
- JANGAN buat file complete-settings.html duplikat, admin resmi hanya btp-admin/index.html dan btp-admin/clients.html, btp-admin/edit.html
- JANGAN ubah HEAD CORE a19cb3f tanpa izin
- JANGAN pakai schema lama app_config(device_id, key, value)
- JANGAN hapus /docs/permanent/, akumulasi permanen

### Prioritas Eksekusi Saat Ini:
Lihat DOC_00_MASTER_ROADMAP.md - Kerjakan PRIORITAS yang belum LIVE sampai selesai baru lanjut next. Jangan kerjakan semua sekaligus.

### Jika Kamu Bingung:
Baca DOC_00 dulu, lalu cek https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/ apakah LIVE.
