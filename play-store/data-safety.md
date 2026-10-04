# Google Play Data Safety — Berkah Tiga Puteri POS

Dokumen ini adalah jawaban kerja untuk build Final Pos UAT yang saat ini membuka `HomeScreen` konfigurasi/verification, bukan alur kasir produksi. Jawaban final Play Console harus tetap dicocokkan dengan AAB yang benar-benar dirilis dan SDK yang terkandung di dalamnya.

## Build yang dicakup

UI yang saat ini reachable menyediakan:

- pemilihan tenant/device;
- status sumber konfigurasi/Supabase;
- refresh konfigurasi;
- preview MDR efektif POS;
- status ketersediaan POS/Akuntansi.

HomeScreen saat ini tidak membuka checkout kasir, transaksi QRIS, atau laporan PPN. Dokumen ini tidak mengklaim flow tersebut sebagai UI rilis yang aktif.

## Data yang dapat diproses build UAT

- tenant ID dan device ID;
- konfigurasi efektif dan feature/service availability;
- status sinkronisasi/config source;
- data autentikasi Supabase jika sesi perangkat diprovisikan (misalnya user ID/identifier akun yang diperlukan untuk otorisasi).

Data aplikasi yang lebih luas dapat ada di modul repository, tetapi deklarasi Play Console harus mengikuti data yang benar-benar dikumpulkan oleh build yang dirilis.

## Keamanan dan akses cloud

Final Pos menggunakan Supabase melalui HTTPS/TLS. Service-role key tidak boleh berada di APK atau browser client.

Model akses Final Pos saat ini:

- `anon` tidak mempunyai direct SELECT pada `tenants`, `devices`, `licences`, `app_config`, atau `tenant_services`;
- `anon` tidak dapat menjalankan `get_effective_config(...)`;
- cloud effective-config access memerlukan sesi `authenticated`;
- caller perangkat normal dibatasi oleh `devices.user_id = auth.uid()`;
- RPC juga memvalidasi bahwa device benar-benar milik tenant yang diminta;
- `service_role` hanya untuk proses server/CI/admin yang dipercaya.

Publishable key bukan izin untuk membaca data secara anonim.

## Sharing / selling

Data tidak dijual dan tidak dibagikan untuk periklanan atau pemasaran. Supabase dapat memproses data sebagai penyedia layanan backend sejauh diperlukan untuk fungsi aplikasi.

## Encryption

Data yang dikirim ke Supabase menggunakan koneksi HTTPS/TLS.

## Sebelum submit Play Console

Sebelum submit, cocokkan kembali dokumen ini dengan AAB produksi, sesi autentikasi yang benar-benar dipakai, permission Android, serta seluruh SDK analytics/crash/payment/ads yang benar-benar disertakan. Jika build mulai membuka cashier, QRIS, PPN, atau pengumpulan transaksi, Data Safety harus diperbarui sebelum rilis tersebut.
