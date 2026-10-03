# DOC_05 - FEATURE FLAGS 2 LAYANAN POS + AKUNTANSI

## Contract
Feature entitlement tenant disimpan di `tenants.features` JSONB:

```json
{"pos": true, "akuntansi": false}
```

Dua boolean canonical:
- `features.pos`
- `features.akuntansi`

Admin dan APK harus membaca feature flag tenant sebelum menampilkan/mengaktifkan layanan. Jika `features.akuntansi=false`, menu dan field konfigurasi akuntansi harus disembunyikan atau dinonaktifkan. Feature flag bukan pengganti RLS; write tetap wajib authenticated.

## Contoh client
### Client A - POS saja
```json
{"pos": true, "akuntansi": false}
```
APK menampilkan POS dan menyembunyikan menu Akuntansi.

POS service config tetap punya key tenant sendiri:

```text
tenant:clientA:service:pos
```

dengan contoh MDR `0.5` persen.

### Client B - POS + Akuntansi
```json
{"pos": true, "akuntansi": true}
```
Dua layanan aktif. POS dapat memakai MDR berbeda dari client A tanpa tabrakan karena key berbeda:

```text
tenant:clientB:service:pos
```

dengan contoh MDR `0.7` persen.

Akuntansi client B memakai:

```text
tenant:clientB:service:akuntansi
```

## Anti-tabrakan
Konfigurasi service selalu scoped oleh tenant ID:

- `tenant:clientA:service:pos`
- `tenant:clientB:service:pos`
- `tenant:clientB:service:akuntansi`

Perubahan MDR client A tidak boleh mengubah client B. Jangan menyimpan MDR tenant tertentu pada `global`.

## UI Admin
`btp-admin/edit.html` memiliki checkbox `POS` dan `AKUNTANSI`.

- AKUNTANSI OFF -> seluruh field scope akuntansi, termasuk akun `2-2010`, dinonaktifkan.
- AKUNTANSI ON -> field akuntansi aktif kembali.
- SAVE TENANT menyimpan `tenants.features` bersama metadata tenant.

## Seed verification
SQL contoh tersedia di `DOC_05_FEATURE_FLAGS.sql`.

**Copy paste ini di Supabase SQL Editor** jika ingin membuat client A dan client B untuk UAT. ChatGPT tidak menjalankan SQL tersebut langsung.
