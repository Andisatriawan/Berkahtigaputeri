# DOC_06 - AUDIT LOG + ANTI-TABRAKAN VERSIONING

Status: **LIVE / P5** — diterapkan dan diverifikasi pada 2026-10-04.

## Fondasi audit LIVE

Tabel permanen:

```text
config_history(id, key, old_value, new_value, changed_by, changed_at, version)
```

Trigger LIVE pada `app_config`:

```text
trg_app_config_audit -> log_config_change()
```

`log_config_change()` berjalan sebagai `SECURITY INVOKER`, sehingga audit tidak menjadi bypass RLS. Write `app_config` tetap tunduk pada policy authenticated super admin dan setiap INSERT/UPDATE yang lolos dicatat ke `config_history`.

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

## Verifikasi LIVE P5

Pada 2026-10-04 dilakukan SAVE terkontrol pada:

```text
tenant:berkah_sumber
```

Hasil:

```text
old version = 1
new version = 2
changed_by = satria@berkahtigaputeri.com
```

Record tersebut tercatat otomatis oleh trigger pada `config_history`, membuktikan setiap SAVE `app_config` yang berhasil menghasilkan audit record.

SQL verifikasi:

```sql
select key, version, changed_by, changed_at, old_value, new_value
from config_history
where key = 'tenant:berkah_sumber'
order by changed_at desc
limit 20;
```

## Acceptance anti-tabrakan dua admin/tab

1. Buka tenant yang sama di Tab A dan Tab B.
2. Keduanya load version yang sama.
3. SAVE di Tab A -> version bertambah.
4. Tanpa reload Tab B, klik SAVE.
5. Tab B membandingkan `dbVersion` dengan `loadedVersion`.
6. Jika berbeda, write dibatalkan dan muncul `Config sudah diupdate orang lain, reload?`.

Implementasi berada di `btp-admin/editor-core.js`; history UI berada di `btp-admin/history.html`.
