# DOC_06 - AUDIT LOG + ANTI-TABRAKAN VERSIONING

## Fondasi audit yang sudah ditetapkan
`DOC_02_SUPABASE_SCHEMA_V1.sql` mendefinisikan tabel permanen:

```text
config_history(id, key, old_value, new_value, changed_by, changed_at, version)
```

`DOC_03_RLS_AUTH.sql` mendefinisikan trigger/function audit `log_config_change` untuk mencatat perubahan `app_config` ke `config_history`.

Jika SQL tersebut belum diterapkan pada project Supabase LIVE, **copy paste `DOC_02_SUPABASE_SCHEMA_V1.sql` lalu `DOC_03_RLS_AUTH.sql` di Supabase SQL Editor**. ChatGPT tidak menjalankan SQL ini langsung.

## Version contract
Setiap `app_config.value` membawa integer `version`.

Saat halaman editor load, UI menyimpan version yang dibaca. Tepat sebelum SAVE, UI membaca row database lagi:

1. `loadedVersion` = version saat form dibuka/reload.
2. `dbVersion` = version terkini tepat sebelum write.
3. Jika sama, save boleh lanjut dan menulis `version = dbVersion + 1`.
4. Jika berbeda, save **dibatalkan** dan UI menampilkan:

> Config sudah diupdate orang lain, reload?

Jika admin memilih reload, editor mengambil ulang konfigurasi terbaru sebelum admin melakukan perubahan lagi.

Ini adalah optimistic concurrency check untuk mencegah silent overwrite ketika dua admin mengedit key yang sama.

## Audit UI
Buka:

`/btp-admin/history.html?key=tenant:berkah_sumber`

Halaman authenticated ini membaca `config_history` dan menampilkan:
- version
- changed_at
- changed_by
- old_value
- new_value

## Acceptance P5
### Audit
1. Login sebagai super admin.
2. Load `edit.html?tenant=berkah_sumber`.
3. SAVE TENANT satu kali.
4. Buka history key `tenant:berkah_sumber`.
5. Harus ada record baru setelah trigger audit SQL sudah aktif.

Verifikasi SQL:

```sql
select key, version, changed_by, changed_at, old_value, new_value
from config_history
where key = 'tenant:berkah_sumber'
order by changed_at desc
limit 20;
```

### Anti-tabrakan dua admin/tab
1. Buka tenant yang sama di Tab A dan Tab B.
2. Keduanya load version yang sama.
3. SAVE di Tab A -> version bertambah.
4. Tanpa reload Tab B, klik SAVE.
5. Tab B harus melihat `Config sudah diupdate orang lain, reload?` dan write kedua tidak boleh menimpa perubahan Tab A.
