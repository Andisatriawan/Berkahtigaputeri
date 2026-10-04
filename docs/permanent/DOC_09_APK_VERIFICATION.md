# DOC_09 - APK VERIFICATION P6

Status target: P6 APK membaca config canonical 3 layer + feature flag layanan.

## Implementasi

Flutter app berada di `pos-app/`.

File P6:
- `lib/core/config/config_service.dart` - RPC `get_effective_config`, fallback SELECT `app_config`, merge canonical, cache offline.
- `lib/core/config/app_identity_store.dart` - persist `tenant_id` dan `device_id`.
- `lib/features/home/home_screen.dart` - selector tenant UAT, MDR efektif, menu POS/Akuntansi berdasarkan `tenants.features`.
- `lib/main.dart` - Supabase client menggunakan Publishable Key, bukan service-role key.
- `test/config/config_service_test.dart` - test urutan merge dan feature flag clientA/clientB.

Urutan merge canonical:

```text
GLOBAL <- TENANT <- SERVICE <- DEVICE
```

Key yang dibaca untuk POS:

```text
global
tenant:<tenant_id>
tenant:<tenant_id>:service:pos
device:<device_id>
```

APK mencoba RPC terlebih dahulu:

```text
get_effective_config(p_tenant, p_device, p_service)
```

Jika RPC gagal tetapi Data API masih dapat diakses, APK fallback ke SELECT `app_config` dan merge lokal dengan urutan yang sama. Jika jaringan/Data API tidak tersedia, hasil terakhir dibaca dari SharedPreferences cache.

## Supabase LIVE verification

RPC dibuat pada project staging yang sama dengan btp-admin.

Manual rebuild instruction:

> Copy paste `docs/permanent/DOC_08_RPC_EFFECTIVE_CONFIG.sql` di Supabase SQL Editor dan Run.

Test SQL:

```sql
SELECT get_effective_config('berkah_sumber','infinix_xos_123','pos');
```

Evidence yang sudah diverifikasi:

```text
berkah_sumber POS MDR = 0.7
clientA       POS MDR = 0.5
clientB       POS MDR = 0.7

clientA features = {pos:true, akuntansi:false}
clientB features = {pos:true, akuntansi:true}
```

RPC juga diuji sebagai role `anon`; `clientA` mengembalikan MDR `0.5`. RLS tetap menolak write anonim.

## Test clientA

1. Jalankan app.
2. Pada `Settings / Tenant UAT`, pilih `clientA`.
3. Device UAT: `infinix_xos_123`.
4. Refresh config.
5. Expected:
   - status `LIVE SUPABASE` saat online;
   - `MDR efektif POS: 0.5%`;
   - menu `POS` terlihat;
   - menu `Akuntansi` tidak dirender.

Log expected:

```text
tenant=clientA
service=pos
mdr=0.5
features.pos=true
features.akuntansi=false
```

## Test clientB

1. Pilih `clientB`.
2. Refresh config.
3. Expected:
   - `MDR efektif POS: 0.7%`;
   - menu `POS` terlihat;
   - menu `Akuntansi` terlihat.

Log expected:

```text
tenant=clientB
service=pos
mdr=0.7
features.pos=true
features.akuntansi=true
```

## Test offline cache

1. Saat online, pilih `clientA` dan tunggu config sukses.
2. Aktifkan airplane mode.
3. Restart/reload screen.
4. Expected: status `CACHE OFFLINE`, MDR tetap `0.5%`, menu Akuntansi tetap hilang.
5. Ulangi untuk `clientB`; expected MDR `0.7%` dan Akuntansi tetap terlihat.

Cache key:

```text
p6.effective.<tenant>.<device>.<service>
p6.features.<tenant>
```

## Screenshot / runtime log

Untuk acceptance device, ambil screenshot berikut:
- `clientA`: header tenant + `MDR efektif POS: 0.5%` + hanya menu POS.
- `clientB`: header tenant + `MDR efektif POS: 0.7%` + menu POS dan Akuntansi.
- airplane mode: badge/status `CACHE OFFLINE`.

Pada eksekusi P6 ini runtime Android belum dapat dibuktikan di emulator karena repository hanya memiliki `pos-app/android/app/build.gradle`; `AndroidManifest.xml`, MainActivity, root Gradle/settings dan Gradle wrapper tidak ada. Kode Flutter P6 dan database/RPC dapat diverifikasi, tetapi screenshot APK installable harus dilakukan setelah Android scaffolding dipulihkan/digenerate.

## Anti-tabrakan tenant

APK tidak mengambil `tenant_id` dari JSON effective sebagai identitas session. Identitas tenant berasal dari `AppIdentityStore`. Ini penting saat satu device UAT dipakai bergantian untuk `berkah_sumber`, `clientA`, dan `clientB`.

MDR tetap tenant-scoped:

```text
tenant:clientA:service:pos -> 0.5%
tenant:clientB:service:pos -> 0.7%
```

## Pages regression

P6 tidak mengubah file di `btp-admin/` dan tidak mengubah `.github/workflows/pages.yml`.

Setelah commit P6, workflow `Deploy btp-admin to GitHub Pages` harus tetap SUCCESS dan artifact harus tetap memuat:
- `btp-admin/clients.html`
- `btp-admin/edit.html`
- `btp-admin/history.html`
