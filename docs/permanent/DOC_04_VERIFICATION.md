# DOC_04 VERIFICATION - SUPER ADMIN CLIENTS + EDIT

## Preconditions
- `DOC_02_SUPABASE_SCHEMA_V1.sql` sudah diaplikasikan di Supabase SQL Editor.
- `DOC_03_RLS_AUTH.sql` sudah diaplikasikan di Supabase SQL Editor.
- Login sebagai `satria@berkahtigaputeri.com`.

## Clients list
Buka `/btp-admin/clients.html`.

Expected:
- tabel `tenants` tampil;
- seed `berkah_sumber` tampil jika DOC_02 sudah dijalankan;
- search tenant/toko berfungsi;
- filter paket `basic/pro/enterprise` berfungsi;
- filter blocked berfungsi;
- expiry kurang dari 7 hari ditandai merah;
- `last_seen` berasal dari `devices.last_seen_at` terbaru per tenant;
- tombol Add Tenant dan Edit tersedia.

## Edit tenant
Buka `/btp-admin/edit.html?tenant=berkah_sumber`.

Expected:
- kontrak form tetap 43 field;
- editor memilih device pertama tenant (`infinix_xos_123` pada seed);
- load 5 key: global, tenant, service POS, service AKUNTANSI, device;
- inheritance ditampilkan sebagai `GLOBAL + TENANT + SERVICE POS/AKUNTANSI + DEVICE`, dengan DEVICE tertinggi;
- 5 tombol SAVE menulis ke key masing-masing;
- SAVE TENANT juga sinkronkan metadata `tenants`;
- SAVE DEVICE juga sinkronkan metadata `devices`.

## Root admin
`/btp-admin/` harus mengarahkan session authenticated ke `clients.html`, dan session tanpa login ke `login.html`.
