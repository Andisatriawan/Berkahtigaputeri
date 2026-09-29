// lib/features/accounting/models/coa_account.dart

/// Supported accounting categories for the approved chart of accounts.
enum CoaAccountType {
  asset,
  liability,
  equity,
  revenue,
  cogs,
  expense,
}

/// Immutable chart-of-accounts model.
class CoaAccount {
  const CoaAccount({
    required this.code,
    required this.nameId,
    required this.type,
  });

  final String code;
  final String nameId;
  final CoaAccountType type;
}

/// Approved accounts sourced exclusively from docs/COA.md.
class CoaAccounts {
  CoaAccounts._();

  static const CoaAccount cash = CoaAccount(
    code: '1-1010',
    nameId: 'Kas Tunai',
    type: CoaAccountType.asset,
  );
  static const CoaAccount qris = CoaAccount(
    code: '1-1020',
    nameId: 'QRIS Clearing',
    type: CoaAccountType.asset,
  );
  static const CoaAccount bankTransfer = CoaAccount(
    code: '1-1030',
    nameId: 'Bank Transfer',
    type: CoaAccountType.asset,
  );
  static const CoaAccount inventory = CoaAccount(
    code: '1-1040',
    nameId: 'Persediaan Barang',
    type: CoaAccountType.asset,
  );
  static const CoaAccount accountsReceivable = CoaAccount(
    code: '1-1050',
    nameId: 'Piutang Usaha',
    type: CoaAccountType.asset,
  );
  static const CoaAccount storeEquipment = CoaAccount(
    code: '1-1060',
    nameId: 'Peralatan Toko',
    type: CoaAccountType.asset,
  );
  static const CoaAccount accumulatedDepreciation = CoaAccount(
    code: '1-1070',
    nameId: 'Akumulasi Penyusutan Peralatan',
    type: CoaAccountType.asset,
  );

  static const CoaAccount ppnPayable = CoaAccount(
    code: '2-2010',
    nameId: 'Utang PPN 11%',
    type: CoaAccountType.liability,
  );
  static const CoaAccount supplierPayable = CoaAccount(
    code: '2-2020',
    nameId: 'Utang Supplier',
    type: CoaAccountType.liability,
  );
  static const CoaAccount salaryPayable = CoaAccount(
    code: '2-2030',
    nameId: 'Utang Gaji',
    type: CoaAccountType.liability,
  );

  static const CoaAccount ownerCapital = CoaAccount(
    code: '3-3010',
    nameId: 'Modal Pemilik',
    type: CoaAccountType.equity,
  );
  static const CoaAccount retainedEarnings = CoaAccount(
    code: '3-3020',
    nameId: 'Laba Ditahan',
    type: CoaAccountType.equity,
  );
  static const CoaAccount ownerDrawings = CoaAccount(
    code: '3-3030',
    nameId: 'Prive',
    type: CoaAccountType.equity,
  );

  static const CoaAccount sales = CoaAccount(
    code: '4-4010',
    nameId: 'Penjualan',
    type: CoaAccountType.revenue,
  );
  static const CoaAccount salesDiscounts = CoaAccount(
    code: '4-4020',
    nameId: 'Diskon Penjualan',
    type: CoaAccountType.revenue,
  );
  static const CoaAccount salesReturns = CoaAccount(
    code: '4-4030',
    nameId: 'Retur Penjualan',
    type: CoaAccountType.revenue,
  );
  static const CoaAccount cashOverageIncome = CoaAccount(
    code: '4-4040',
    nameId: 'Selisih Kas Lebih',
    type: CoaAccountType.revenue,
  );

  static const CoaAccount cogs = CoaAccount(
    code: '5-5010',
    nameId: 'Harga Pokok Penjualan',
    type: CoaAccountType.cogs,
  );

  static const CoaAccount salaryExpense = CoaAccount(
    code: '6-6010',
    nameId: 'Beban Gaji',
    type: CoaAccountType.expense,
  );
  static const CoaAccount cashShortageExpense = CoaAccount(
    code: '6-6020',
    nameId: 'Beban Selisih Kas Kurang',
    type: CoaAccountType.expense,
  );
  static const CoaAccount storeOperationalExpense = CoaAccount(
    code: '6-6030',
    nameId: 'Beban Operasional Toko',
    type: CoaAccountType.expense,
  );
  static const CoaAccount rentExpense = CoaAccount(
    code: '6-6040',
    nameId: 'Beban Sewa',
    type: CoaAccountType.expense,
  );
  static const CoaAccount utilitiesExpense = CoaAccount(
    code: '6-6050',
    nameId: 'Beban Listrik dan Air',
    type: CoaAccountType.expense,
  );
  static const CoaAccount depreciationExpense = CoaAccount(
    code: '6-6060',
    nameId: 'Beban Penyusutan',
    type: CoaAccountType.expense,
  );

  static const List<CoaAccount> all = <CoaAccount>[
    cash,
    qris,
    bankTransfer,
    inventory,
    accountsReceivable,
    storeEquipment,
    accumulatedDepreciation,
    ppnPayable,
    supplierPayable,
    salaryPayable,
    ownerCapital,
    retainedEarnings,
    ownerDrawings,
    sales,
    salesDiscounts,
    salesReturns,
    cashOverageIncome,
    cogs,
    salaryExpense,
    cashShortageExpense,
    storeOperationalExpense,
    rentExpense,
    utilitiesExpense,
    depreciationExpense,
  ];

  static CoaAccount? findByCode(String code) {
    for (final account in all) {
      if (account.code == code) {
        return account;
      }
    }
    return null;
  }
}
