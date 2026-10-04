# Berkahtigaputeri

## 🤖 AI AGENT COMPLIANCE - WAJIB BACA

**Jika kamu AI/Agent baru yang akses repo ini, baca ini dulu:**

Repo ini punya **dokumen permanen** di `/docs/permanent/` yang harus jadi compliance karena context window ChatGPT terbatas.

### Baca urut:
1. `DOC_00_MASTER_ROADMAP.md` - Prioritas eksekusi
2. `DOC_01_3_LAYER_CONFIG.md` - 3 Layer: GLOBAL (`global`), TENANT (`tenant:<id>` + `service:pos`/`service:akuntansi`), DEVICE (`device:<id>`)
3. `DOC_02_SUPABASE_SCHEMA_V1.sql` - Schema Supabase live
4. `DOC_03_RLS_AUTH.sql`
5. `DOC_04_ADMIN_ARCHITECTURE.md`

### Live Admin:
https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/

### Aturan:
- Schema: `app_config(key PRIMARY KEY, value JSONB)` - bukan `(device_id, key, value)` lama
- Admin resmi hanya `btp-admin/` - jangan bikin `complete-settings.html` duplikat
- HEAD CORE `a19cb3f CI #315 SUCCESS` jangan diubah
- `/docs/permanent/` adalah akumulasi permanen, jangan hapus

## Final Pos - 100 Tenants SaaS (Excel A + Web C Template)

Final production sekarang memakai satu workbook bulk + satu Template Admin untuk mengelola 100 tenant secara scalable tanpa satu-sheet-per-tenant.

- GitHub Pages Template Admin: https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/final-pos-template-admin.html
- Excel canonical: `config/FINAL_Production_Excel_A_WebC_Template_100Tenants.xlsx`
- Sync script: `scripts/sync_excel_to_supabase.py`
- Workflow: `.github/workflows/final-pos-sync.yml`
- Supabase source of truth: `app_config(key, value)` dengan 352 key canonical dari workbook: 1 global + 3 templates + 100 tenants + 140 services + 108 devices.

Inheritance Final Pos:

```text
GLOBAL -> TEMPLATE -> TENANT -> SERVICE -> DEVICE
```

Service rows yang berasal dari template tetap disimpan untuk audit/export, tetapi MDR efektif diwarisi dari template sampai ada override eksplisit. Dengan demikian perubahan `template:PRO` otomatis berlaku ke seluruh tenant PRO tanpa menduplikasi konfigurasi per toko.
