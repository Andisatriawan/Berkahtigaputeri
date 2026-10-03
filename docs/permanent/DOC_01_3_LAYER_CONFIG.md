# DOC_01 - 3 LAYER CONFIG (GLOBAL, TENANT, DEVICE)

Repo: berkah-ajb-dev/Berkahtigaputeri  
Branch aktif: feat/simulated-hardware-supabase-admin-a19cb3f  
HEAD CORE: a19cb3f CI #315 SUCCESS - JANGAN DIUBAH TANPA IZIN

## Tujuan

Konfigurasi SaaS harus bisa dipakai banyak client tanpa saling menimpa. Setiap tenant dapat memiliki dua layanan berbeda, POS dan AKUNTANSI, sementara setiap device kasir tetap dapat memiliki override hardware sendiri.

Single source of truth konfigurasi adalah tabel:

```text
app_config(key PRIMARY KEY, value JSONB, updated_at)
```

Schema lama `app_config(device_id, key, value)` tidak boleh dipakai.

## Layer 1 - GLOBAL

Key wajib:

```text
key='global'
```

`value` JSONB berisi default untuk semua tenant/device, misalnya default PPN, akun, payment enablement, MDR, hardware mode, printer/drawer, FEFO/FIFO, dan shift immutable.

## Layer 2 - TENANT + 2 Layanan

Key tenant utama:

```text
key='tenant:<id>'
```

Key layanan POS:

```text
key='tenant:<id>:service:pos'
```

Key layanan Akuntansi:

```text
key='tenant:<id>:service:akuntansi'
```

Tujuannya agar satu client dapat memakai konfigurasi POS dan AKUNTANSI secara terpisah. Contoh:

```text
tenant:berkah_sumber:service:pos
  {qris_enabled:true, transfer_enabled:false}

tenant:berkah_sumber:service:akuntansi
  {auto_jurnal:true}
```

Perubahan pada `tenant:clientA:service:pos` tidak boleh mengubah `global`, tenant lain, atau layanan akuntansi tenant tersebut.

## Layer 3 - DEVICE

Key wajib:

```text
key='device:<id>'
```

Layer ini untuk override per HP/kasir, termasuk identitas device dan konfigurasi hardware seperti `hardware_mode`, `printer_type`, dan kebutuhan device spesifik lainnya.

Contoh:

```text
key='device:infinix_xos_123'
```

## Inheritance / Merge Override

Urutan inheritance wajib:

```text
GLOBAL -> TENANT -> DEVICE
```

Artinya default berasal dari `global`, kemudian dioverride oleh konfigurasi tenant/service yang relevan, lalu terakhir oleh konfigurasi device yang relevan. Override harus merge, bukan menghapus konfigurasi layer sebelumnya yang tidak dioverride.

## Lima Key Minimum untuk Tenant Pilot

Untuk tenant `berkah_sumber` dan device `infinix_xos_123`, `app_config` harus memiliki minimal lima row berikut:

```text
global
tenant:berkah_sumber
tenant:berkah_sumber:service:pos
tenant:berkah_sumber:service:akuntansi
device:infinix_xos_123
```

## Compliance

- Jangan kembali ke schema lama `app_config(device_id, key, value)`.
- Jangan gabungkan POS dan AKUNTANSI menjadi satu service key jika keduanya perlu konfigurasi berbeda.
- Jangan menulis config tenant ke `global`.
- Jangan menulis config device ke tenant key.
- Semua implementasi admin dan APK harus mengikuti key contract di dokumen ini.
- SQL seed dan contoh implementasi lihat `DOC_02_SUPABASE_SCHEMA_V1.sql` dan `DOC_04_ADMIN_ARCHITECTURE.md`.
