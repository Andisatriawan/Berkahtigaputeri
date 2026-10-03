# DOC_03 VERIFICATION - RLS + SUPER ADMIN AUTH

## SQL yang harus diaplikasikan
File sumber: `docs/permanent/DOC_03_RLS_AUTH.sql`.

**Copy paste ini di Supabase SQL Editor**: buka isi `DOC_03_RLS_AUTH.sql`, jalankan seluruh file, lalu pastikan tidak ada error. ChatGPT tidak menjalankan SQL ini langsung.

## Acceptance anon read / anon write
1. Buka `btp-admin/login.html`, simpan Supabase URL + Anon/Publishable Key tanpa login.
2. Query SELECT ke `app_config` dengan anon boleh sesuai policy read.
3. Upsert/UPDATE anon ke `app_config` harus gagal oleh RLS.

Contoh pengecekan policy dari SQL Editor:
```sql
select schemaname, tablename, policyname, roles, cmd
from pg_policies
where tablename in ('tenants','devices','licences','app_config','config_history')
order by tablename, policyname;
```

## Acceptance authenticated write
1. Login di `btp-admin/login.html` sebagai `satria@berkahtigaputeri.com`.
2. Buka halaman editor.
3. SAVE salah satu layer.
4. Save harus berhasil karena JWT authenticated dan email sesuai policy super-admin.
5. Logout, ulangi write tanpa session: harus gagal.

## URL
- `/btp-admin/login.html`
- `/btp-admin/`

## Security boundary
- Browser hanya menggunakan Anon/Publishable Key.
- Service-role key tidak boleh ditaruh di HTML, localStorage, atau repository.
- `auth.js` memvalidasi session email sebelum fungsi write dijalankan; RLS tetap menjadi enforcement utama di database.
