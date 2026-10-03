# DOC_07 - FINAL VERIFICATION P1-P5

## URL admin yang harus diverifikasi LIVE
- Root admin: `https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/`
- Login: `https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/login.html`
- Clients: `https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/clients.html`
- Edit pilot: `https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/edit.html?tenant=berkah_sumber`
- History pilot: `https://berkah-ajb-dev.github.io/Berkahtigaputeri/btp-admin/history.html?key=tenant%3Aberkah_sumber`

## Prerequisite database
Admin UI bergantung pada schema/RLS yang didefinisikan di dokumen permanen.

Jika belum diterapkan, **copy paste file berikut secara berurutan di Supabase SQL Editor**:

1. `DOC_02_SUPABASE_SCHEMA_V1.sql`
2. `DOC_03_RLS_AUTH.sql`

Untuk UAT 2 client, opsional copy paste:

3. `DOC_05_FEATURE_FLAGS.sql`

ChatGPT tidak menjalankan SQL tersebut langsung.

## Test P1 - 3 layer + 2 service
Pastikan 5 key pilot ada:

```sql
select key, value->>'version' as version, updated_at
from app_config
where key in (
  'global',
  'tenant:berkah_sumber',
  'tenant:berkah_sumber:service:pos',
  'tenant:berkah_sumber:service:akuntansi',
  'device:infinix_xos_123'
)
order by key;
```

Di editor, nilai efektif harus merupakan merge `GLOBAL + TENANT + SERVICE POS/AKUNTANSI + DEVICE`, dengan DEVICE override tertinggi. Lima tombol SAVE harus menulis ke lima key yang tepat dan menaikkan `value.version`.

## Test P2 - RLS + Auth
- Tanpa session authenticated, halaman write harus mengarahkan ke login.
- Login dengan super admin `satria@berkahtigaputeri.com`.
- Browser hanya memakai Anon/Publishable Key; jangan pernah memasukkan service-role key.
- Anon write ke `app_config` harus gagal setelah `DOC_03_RLS_AUTH.sql` aktif.
- Authenticated super-admin write harus berhasil.

## Test P3 - banyak client
Buka `clients.html`:
- seed `berkah_sumber` tampil;
- search/filter paket/filter blocked bekerja;
- expiry < 7 hari ditandai merah;
- `last_seen` berasal dari device terbaru;
- klik Edit membuka `edit.html?tenant=berkah_sumber` dengan 43 field dan inheritance 3 layer.

## Test P4 - 2 layanan dan anti tabrakan antar-client
Jalankan `DOC_05_FEATURE_FLAGS.sql` untuk UAT jika client A/B belum ada.

Expected:
- `clientA`: `features={pos:true, akuntansi:false}` -> field/menu akuntansi disabled/hidden; POS tetap aktif.
- `clientB`: `features={pos:true, akuntansi:true}` -> POS + Akuntansi aktif.
- `tenant:clientA:service:pos` memakai MDR contoh 0.5%.
- `tenant:clientB:service:pos` memakai MDR contoh 0.7%.
- Mengubah config client A tidak mengubah key client B.

SQL verifikasi:

```sql
select tenant_id, features
from tenants
where tenant_id in ('clientA','clientB')
order by tenant_id;

select key, value
from app_config
where key like 'tenant:clientA:service:%'
   or key like 'tenant:clientB:service:%'
order by key;
```

## Test P5 - audit + optimistic concurrency
1. Buka tenant yang sama di dua tab.
2. Keduanya load version yang sama.
3. Tab A SAVE -> version naik.
4. Tab B SAVE tanpa reload -> UI harus menampilkan `Config sudah diupdate orang lain, reload?` dan write Tab B dibatalkan.
5. Buka `history.html?key=tenant:berkah_sumber`; setiap perubahan `app_config` harus muncul setelah trigger audit SQL aktif.

SQL verifikasi:

```sql
select key, version, changed_by, changed_at, old_value, new_value
from config_history
where key = 'tenant:berkah_sumber'
order by changed_at desc
limit 20;
```

## Deployment acceptance
Workflow `.github/workflows/pages.yml` membangun artifact dengan layout `_site/btp-admin/`, sehingga path publik tetap `/Berkahtigaputeri/btp-admin/`. Deployment production hanya dipicu dari `main` agar feature branch tidak menimpa Pages production.

Final acceptance harus dicatat hanya setelah GitHub Pages workflow selesai `success` dan URL di atas merespons dari deployment terbaru.
