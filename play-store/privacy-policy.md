# Kebijakan Privasi — Berkah Tiga Puteri POS

Berlaku untuk build Final Pos UAT saat ini.

Build yang sekarang dibuka dari `main.dart` adalah HomeScreen konfigurasi/verification. UI reachable menyediakan pemilihan tenant/device, status Supabase/config source, refresh konfigurasi, preview konfigurasi efektif, dan status layanan POS/Akuntansi. HomeScreen belum membuka alur checkout kasir, transaksi QRIS, atau laporan PPN.

## Data yang diproses

Untuk fungsi UAT/config, aplikasi dapat memproses tenant ID, device ID, konfigurasi efektif, status layanan, status sinkronisasi, dan data autentikasi yang diperlukan apabila sesi perangkat diprovisikan.

Modul repository lain dapat menangani data POS/akuntansi, tetapi kebijakan rilis harus selalu disesuaikan dengan fitur dan data yang benar-benar reachable pada build yang dipublikasikan.

## Supabase dan keamanan akses

Aplikasi menggunakan Supabase sebagai backend. Data yang dikirim ke backend menggunakan HTTPS/TLS.

Final Pos tidak menyediakan anonymous read untuk data konfigurasi tenant:

- role `anon` tidak mempunyai direct SELECT pada tabel Final Pos (`tenants`, `devices`, `licences`, `app_config`, `tenant_services`);
- role `anon` tidak dapat menjalankan `get_effective_config(...)`;
- akses cloud effective-config memerlukan sesi authenticated;
- pengguna/perangkat authenticated normal dibatasi ke device yang dimiliki melalui `devices.user_id = auth.uid()`;
- RPC memvalidasi device tersebut berada pada tenant yang diminta;
- `service_role` hanya digunakan pada proses server/administratif yang dipercaya dan tidak boleh ditanamkan di APK.

Publishable key Supabase bukan kredensial untuk membaca data tenant secara anonim.

## Penjualan dan pembagian data

Kami tidak menjual data pengguna dan tidak membagikannya untuk periklanan atau pemasaran. Supabase dapat memproses data sebagai penyedia layanan teknis sejauh diperlukan untuk menyediakan backend aplikasi.

## Retensi, koreksi, dan penghapusan

Retensi mengikuti kebutuhan operasional dan kewajiban yang berlaku. Sebelum rilis produksi, pengelola aplikasi harus mempublikasikan kanal kontak aktif untuk permintaan privasi, koreksi, dan penghapusan data.

## Perubahan kebijakan

Kebijakan ini harus diperbarui sebelum build baru mengaktifkan pengumpulan atau UI baru seperti checkout kasir, transaksi QRIS, laporan PPN, analytics, crash reporting, iklan, atau SDK pihak ketiga lain yang mengubah praktik data.
