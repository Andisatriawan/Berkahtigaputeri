# Chart of Accounts - Berkah Tiga Puteri POS
# PSAK compliant for Indonesian retail SME, PPN 11%

> LOCKED CONTRACT: ChatGPT Codex and all AI agents MUST use these exact codes. Never invent new codes. If a transaction needs a new account, ask first.

## M1 Accounting Core

| Kode | Nama Indonesia | Tipe |
| --- | --- | --- |
| 1-1010 | Kas Tunai | Aset Lancar |
| 1-1020 | QRIS Clearing | Aset Lancar |
| 1-1030 | Bank Transfer | Aset Lancar |
| 1-1040 | Persediaan Barang | Aset Lancar |
| 2-2010 | Utang PPN 11% | Kewajiban |
| 3-3010 | Modal Pemilik | Ekuitas |
| 4-4010 | Penjualan | Pendapatan |
| 5-5010 | Harga Pokok Penjualan | HPP |
| 6-6020 | Beban Selisih Kas Kurang | Beban |


## 1 - ASET / ASSETS

| Kode | Nama Indonesia | Nama English | Tipe | Saldo Normal | Deskripsi |
| --- | --- | --- | --- | --- | --- |
| 1-1010 | Kas Tunai | Cash on Hand | Aset Lancar | Debit | Uang tunai di laci kasir, per shift |
| 1-1020 | QRIS Clearing | QRIS Clearing | Aset Lancar | Debit | Dana QRIS belum masuk bank, settlement H+1 |
| 1-1030 | Bank Transfer | Bank Transfer | Aset Lancar | Debit | Mutasi transfer bank BCA/BRI |
| 1-1040 | Persediaan Barang | Inventory | Aset Lancar | Debit | Stok barang dagangan, metode FIFO |
| 1-1050 | Piutang Usaha | Accounts Receivable | Aset Lancar | Debit | Penjualan kredit pelanggan |
| 1-1060 | Peralatan Toko | Store Equipment | Aset Tetap | Debit | Printer struk, scanner barcode |
| 1-1070 | Akumulasi Penyusutan Peralatan | Accumulated Depreciation | Aset Tetap | Kredit | Kontra aset untuk 1-1060 |

## 2 - KEWAJIBAN / LIABILITIES

| Kode | Nama Indonesia | Nama English | Tipe | Saldo Normal | Deskripsi |
| --- | --- | --- | --- | --- | --- |
| 2-2010 | Utang PPN 11% | PPN Payable 11% | Kewajiban | Kredit | PPN keluaran atas penjualan, lapor bulanan |
| 2-2020 | Utang Supplier | Supplier Payable | Kewajiban | Kredit | Utang pembelian stok ke supplier |
| 2-2030 | Utang Gaji | Salary Payable | Kewajiban | Kredit | Gaji karyawan belum dibayar |

## 3 - EKUITAS / EQUITY

| Kode | Nama Indonesia | Nama English | Tipe | Saldo Normal | Deskripsi |
| --- | --- | --- | --- | --- | --- |
| 3-3010 | Modal Pemilik | Owner Capital | Ekuitas | Kredit | Modal awal Berkah Tiga Puteri |
| 3-3020 | Laba Ditahan | Retained Earnings | Ekuitas | Kredit | Akumulasi laba tahun berjalan |
| 3-3030 | Prive | Owner Drawings | Ekuitas | Debit | Pengambilan pribadi pemilik |

## 4 - PENDAPATAN / REVENUE

| Kode | Nama Indonesia | Nama English | Tipe | Saldo Normal | Deskripsi |
| --- | --- | --- | --- | --- | --- |
| 4-4010 | Penjualan | Sales | Pendapatan | Kredit | Penjualan kotor sebelum diskon dan PPN |
| 4-4020 | Diskon Penjualan | Sales Discounts | Pendapatan | Debit | Kontra 4-4010, diskon per item dan transaksi |
| 4-4030 | Retur Penjualan | Sales Returns | Pendapatan | Debit | Kontra 4-4010, retur barang |
| 4-4040 | Selisih Kas Lebih | Cash Overage Income | Pendapatan | Kredit | Kelebihan kas saat tutup shift |

## 5 - HARGA POKOK PENJUALAN / COGS

| Kode | Nama Indonesia | Nama English | Tipe | Saldo Normal | Deskripsi |
| --- | --- | --- | --- | --- | --- |
| 5-5010 | Harga Pokok Penjualan | Cost of Goods Sold | HPP | Debit | HPP otomatis saat penjualan |

## 6 - BEBAN / EXPENSES

| Kode | Nama Indonesia | Nama English | Tipe | Saldo Normal | Deskripsi |
| --- | --- | --- | --- | --- | --- |
| 6-6010 | Beban Gaji | Salary Expense | Beban | Debit | Gaji kasir dan karyawan |
| 6-6020 | Beban Selisih Kas Kurang | Cash Shortage Expense | Beban | Debit | Kekurangan kas saat tutup shift |
| 6-6030 | Beban Operasional Toko | Store Operational | Beban | Debit | Plastik, struk, ATK |
| 6-6040 | Beban Sewa | Rent Expense | Beban | Debit | Sewa ruko |
| 6-6050 | Beban Listrik dan Air | Utilities Expense | Beban | Debit | Listrik, air, internet |
| 6-6060 | Beban Penyusutan | Depreciation Expense | Beban | Debit | Penyusutan peralatan toko |

---

## POS Posting Rules - WAJIB

### 1. Penjualan Tunai / Cash
```
Dr 1-1010 Kas Tunai (Grand Total)
Cr 4-4010 Penjualan (DPP = Subtotal - Diskon)
Cr 2-2010 Utang PPN 11% (11% x DPP)
Dr 5-5010 HPP
Cr 1-1040 Persediaan Barang
```

### 2. Penjualan QRIS
```
Dr 1-1020 QRIS Clearing (Grand Total)
Cr 4-4010 Penjualan (DPP)
Cr 2-2010 Utang PPN 11%
Dr 5-5010 HPP
Cr 1-1040 Persediaan Barang
```

### 3. Penjualan Transfer Bank
```
Dr 1-1030 Bank Transfer (Grand Total)
Cr 4-4010 Penjualan (DPP)
Cr 2-2010 Utang PPN 11%
Dr 5-5010 HPP
Cr 1-1040 Persediaan Barang
```

### 4. Diskon
Diskon mengurangi DPP sebelum PPN. PPN = 11% x (Subtotal - Diskon). Jangan hitung PPN sebelum diskon.

### 5. Tutup Shift
Jika kas aktual < kas sistem:
```
Dr 6-6020 Beban Selisih Kas Kurang
Cr 1-1010 Kas Tunai
```
Jika kas aktual > kas sistem:
```
Dr 1-1010 Kas Tunai
Cr 4-4040 Selisih Kas Lebih
```

### 6. Retur Penjualan
Reverse dari penjualan awal dengan akun 4-4030.

## Validation Rules for Codex
1. Every JournalEntry must satisfy: sum(Debit) == sum(Credit), else rollback
2. transactionId must be unique, idempotent, no double posting
3. PPN exempt products (ppnExempt=true): no 2-2010 posting for that line
4. Negative stock blocked without managerPin
5. All amounts in integer Rupiah, no decimals
