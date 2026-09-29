// docs/COA.md

# Chart of Accounts (COA)

Dokumen ini adalah sumber kebenaran untuk kode akun yang boleh digunakan oleh aplikasi Berkah Tiga Puteri.

Jangan menambahkan, mengganti, atau menebak kode akun di kode aplikasi tanpa memperbarui dokumen ini berdasarkan keputusan bisnis yang eksplisit.

| Kode | Nama Akun | Jenis | Saldo Normal | Penggunaan |
| --- | --- | --- | --- | --- |
| 1-1010 | Kas | Aset | Debit | Penerimaan pembayaran tunai |
| 1-1020 | QRIS | Aset | Debit | Penerimaan pembayaran QRIS |
| 1-1030 | Bank | Aset | Debit | Penerimaan pembayaran bank |
| 1-1040 | Persediaan | Aset | Debit | Nilai persediaan barang |
| 2-2010 | Utang PPN | Liabilitas | Kredit | PPN keluaran 11% |
| 4-4010 | Penjualan | Pendapatan | Kredit | Penjualan setelah diskon |
| 5-5010 | Harga Pokok Penjualan | Beban | Debit | Harga pokok barang yang terjual |

## Aturan Posting POS

PPN dihitung sebesar 11% dari nilai penjualan setelah diskon.

Posting penerimaan pembayaran:

- Debit 1-1010 Kas untuk pembayaran tunai; atau
- Debit 1-1020 QRIS untuk pembayaran QRIS; atau
- Debit 1-1030 Bank untuk pembayaran bank.
- Kredit 4-4010 Penjualan sebesar nilai penjualan setelah diskon.
- Kredit 2-2010 Utang PPN sebesar PPN 11%.

Posting harga pokok:

- Debit 5-5010 Harga Pokok Penjualan.
- Kredit 1-1040 Persediaan.

## Invarian Akuntansi

Setiap jurnal wajib memenuhi:

`total debit == total kredit`

Jika tidak seimbang, seluruh posting harus ditolak dan tidak boleh ada perubahan yang tersimpan.

Setiap transaksi harus idempoten berdasarkan `transaction_id`: satu `transaction_id` hanya boleh menghasilkan satu jurnal yang tersimpan.
