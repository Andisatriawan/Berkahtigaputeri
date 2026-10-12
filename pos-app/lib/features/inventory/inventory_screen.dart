import 'package:flutter/material.dart';

import '../products/models/product.dart';
import '../products/repositories/sqlite_product_repository.dart';

/// Inventory receipt screen; stock changes create physical lots and cost layers.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.repository,
    required this.onChanged,
  });

  final SqliteProductRepository repository;
  final VoidCallback onChanged;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _unitCost = TextEditingController();
  final _batchNo = TextEditingController();
  List<Product> _products = const <Product>[];
  Product? _selected;
  DateTime? _expiryDate;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unitCost.dispose();
    _batchNo.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final products = await widget.repository.listAll();
      if (!mounted) return;
      setState(() {
        _products = products;
        _selected = _selected == null
            ? (products.isEmpty ? null : products.first)
            : products.where((product) => product.id == _selected!.id).firstOrNull;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String? _positive(String? value, String label) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) return '$label harus lebih dari 0.';
    return null;
  }

  String? _nonNegative(String? value, String label) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) return '$label harus 0 atau lebih.';
    return null;
  }

  Future<void> _chooseExpiryDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? today.add(const Duration(days: 30)),
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 20),
      helpText: 'Pilih tanggal kedaluwarsa',
    );
    if (selected != null && mounted) {
      setState(() => _expiryDate = selected);
    }
  }

  Future<void> _receiveStock() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final product = _selected;
    if (product == null) return;
    if (product.trackExpiry && _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk ini mewajibkan tanggal kedaluwarsa.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final lotId = 'LOT-' + DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final batch = _batchNo.text.trim().isEmpty ? lotId : _batchNo.text.trim();
    try {
      await widget.repository.addInventoryLot(
        id: lotId,
        productId: product.id,
        quantity: int.parse(_quantity.text.trim()),
        unitCost: int.parse(_unitCost.text.trim()),
        acquiredAtUtc: DateTime.now().toUtc(),
        batchNo: batch,
        expiryDate: _expiryDate,
      );
      if (!mounted) return;
      setState(() {
        _quantity.clear();
        _unitCost.clear();
        _batchNo.clear();
        _expiryDate = null;
        _saving = false;
      });
      await _reload();
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Penerimaan stok dan layer biaya tersimpan lokal.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Penerimaan stok gagal: $error')),
      );
    }
  }

  String _dateText(DateTime? date) {
    if (date == null) return 'Tidak ditentukan';
    return date.year.toString().padLeft(4, '0') + '-' +
        date.month.toString().padLeft(2, '0') + '-' +
        date.day.toString().padLeft(2, '0');
  }

  String _money(int amount) => 'Rp ' + amount.toString();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text('Persediaan gagal dimuat: ' + _error!),
          TextButton(
            onPressed: _reload,
            child: const Text('Coba lagi'),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Terima stok',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_products.isEmpty)
                      const Text('Tambahkan produk terlebih dahulu.')
                    else
                      DropdownButtonFormField<Product>(
                        value: _selected,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Produk',
                          border: OutlineInputBorder(),
                        ),
                        items: _products
                            .map(
                              (product) => DropdownMenuItem<Product>(
                                value: product,
                                child: Text(
                                  product.nameId + ' — stok ' +
                                  product.stockQty.toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _selected = value),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah diterima',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _positive(value, 'Jumlah'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _unitCost,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga pokok per unit (Rupiah)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _nonNegative(value, 'Harga pokok'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _batchNo,
                      decoration: InputDecoration(
                        labelText: 'Nomor batch',
                        helperText: _selected?.trackExpiry == true
                            ? 'Wajib untuk produk dengan kedaluwarsa'
                            : 'Opsional; dapat dibuat otomatis',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) => _selected?.trackExpiry == true &&
                              (value == null || value.trim().isEmpty)
                          ? 'Nomor batch wajib diisi.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving || _products.isEmpty
                          ? null
                          : _chooseExpiryDate,
                      icon: const Icon(Icons.event),
                      label: Text('Kedaluwarsa: ' + _dateText(_expiryDate)),
                    ),
                    if (_selected?.trackExpiry == true)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Produk ini menggunakan FEFO; tanggal kedaluwarsa '
                          'wajib dan stok terlalu dekat kedaluwarsa tidak dijual.',
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving || _products.isEmpty
                            ? null
                            : _receiveStock,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_box_outlined),
                        label: Text(_saving ? 'Menyimpan...' : 'Catat penerimaan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ringkasan stok lokal',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ..._products.map(
            (product) => Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(product.nameId),
                subtitle: Text(
                  product.sku + ' · ' +
                  (product.trackExpiry ? 'FEFO' : 'Tanpa pelacakan expiry'),
                ),
                trailing: Text(
                  product.stockQty.toString(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Perubahan di halaman ini masih lokal pada perangkat. Sinkronisasi '
            'stok ke cloud belum aktif pada build ini.',
          ),
        ],
      ),
    );
  }
}
