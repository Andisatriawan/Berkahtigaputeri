# Google Play Data Safety — Berkah Tiga Puteri POS

Dokumen ini adalah jawaban kerja untuk pengisian formulir Data Safety Google Play berdasarkan arsitektur POS yang menggunakan penyimpanan lokal dan Supabase. Jawaban akhir di Play Console harus tetap dicocokkan dengan build produksi yang benar-benar dirilis.

## Ringkasan Jawaban

| Pertanyaan Play Console | Jawaban |
| --- | --- |
| Apakah aplikasi mengumpulkan atau membagikan jenis data pengguna yang wajib dinyatakan? | Ya |
| Apakah data pengguna dibagikan kepada pihak ketiga untuk periklanan atau pemasaran? | Tidak |
| Apakah data pengguna dijual? | Tidak |
| Apakah data dienkripsi saat dikirim? | Ya, untuk sinkronisasi melalui koneksi HTTPS/TLS ke Supabase |
| Apakah pengguna dapat meminta penghapusan data? | Ya, melalui kanal permintaan privasi yang harus dipublikasikan sebelum rilis produksi |
| Apakah aplikasi ditujukan khusus untuk anak? | Tidak |

## Jenis Data yang Dikumpulkan

### Informasi Akun

Jika autentikasi digunakan:

- alamat email;
- user ID atau pengenal akun.

**Tujuan:** autentikasi, pengelolaan akun, keamanan, dan sinkronisasi data.

**Dibagikan:** tidak untuk iklan atau pemasaran. Data dapat diproses oleh Supabase sebagai penyedia layanan backend.

### Informasi Keuangan dan Transaksi Usaha

Aplikasi dapat menyimpan:

- nilai transaksi penjualan;
- metode pembayaran yang dipilih, seperti tunai, QRIS, atau transfer;
- diskon;
- DPP dan PPN;
- harga pokok penjualan;
- data shift dan saldo kas.

Aplikasi tidak dirancang untuk menyimpan nomor kartu penuh, CVV, PIN perbankan, atau kata sandi rekening.

**Tujuan:** fungsi aplikasi, pembukuan, rekonsiliasi, laporan usaha, dan laporan PPN.

**Dibagikan:** tidak untuk periklanan atau pemasaran. Data yang disinkronkan diproses oleh Supabase untuk menyediakan fungsi backend.

### Data Aplikasi dan Operasional Usaha

Aplikasi dapat menyimpan:

- data produk;
- SKU dan barcode;
- stok;
- transaksi tertunda untuk sinkronisasi offline;
- identifier transaksi untuk idempotensi dan pencegahan posting ganda.

**Tujuan:** fungsi POS, pengelolaan persediaan, sinkronisasi, keamanan, dan pencegahan duplikasi.

## Pemrosesan Lokal dan Cloud

Sebagian data dapat disimpan secara lokal pada perangkat untuk mendukung kasir offline.

Data yang perlu disinkronkan dapat dikirim ke Supabase. Supabase diperlakukan sebagai penyedia layanan yang memproses data untuk fungsi backend aplikasi, bukan sebagai penerima data untuk tujuan periklanan.

## Praktik Keamanan yang Dinyatakan

Untuk deklarasi produksi:

- gunakan HTTPS/TLS untuk data yang dikirim ke backend;
- jangan menyimpan service-role key atau rahasia backend di aplikasi Android;
- batasi akses Supabase menggunakan autentikasi dan Row Level Security yang sesuai;
- jangan memasukkan kredensial bank atau data kartu pembayaran sensitif ke catatan POS;
- sediakan prosedur permintaan penghapusan data sebelum publikasi.

## Pemeriksaan Sebelum Submit

Sebelum mengirim Data Safety di Play Console, cocokkan dokumen ini dengan AAB produksi dan seluruh SDK yang benar-benar terdapat di dalam build. Jika SDK analitik, crash reporting, iklan, pembayaran, atau SDK pihak ketiga lain ditambahkan, deklarasi Data Safety harus diperbarui agar mencerminkan data yang benar-benar dikumpulkan atau dibagikan.
