// Screen HRD/Home/asset_stock_management_screen.dart
// CRUD Manajemen Stok Barang Asset (HRD only)
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

// ── DUMMY MODEL (nanti diganti API) ─────────────────────────────────────────
class AssetStockItem {
  final String id;
  String namaBarang;
  String kategori; // Elektronik, ATK, Furniture, dll
  int stok;
  String? deskripsi;
  bool aktif;

  AssetStockItem({
    required this.id,
    required this.namaBarang,
    required this.kategori,
    required this.stok,
    this.deskripsi,
    this.aktif = true,
  });
}

final List<AssetStockItem> _dummyStock = [
  AssetStockItem(
    id: 'A001',
    namaBarang: 'Laptop Lenovo ThinkPad',
    kategori: 'Elektronik',
    stok: 3,
    deskripsi: 'i5, 16GB RAM',
  ),
  AssetStockItem(
    id: 'A002',
    namaBarang: 'Proyektor Epson',
    kategori: 'Elektronik',
    stok: 2,
  ),
  AssetStockItem(
    id: 'A003',
    namaBarang: 'Kamera DSLR Canon',
    kategori: 'Elektronik',
    stok: 1,
  ),
  AssetStockItem(
    id: 'A004',
    namaBarang: 'Bolpoin Pilot',
    kategori: 'ATK',
    stok: 250,
  ),
  AssetStockItem(
    id: 'A005',
    namaBarang: 'Kertas A4 80gr',
    kategori: 'ATK',
    stok: 45,
  ),
  AssetStockItem(
    id: 'A006',
    namaBarang: 'Stapler Kenko',
    kategori: 'ATK',
    stok: 12,
  ),
  AssetStockItem(
    id: 'A007',
    namaBarang: 'Map Plastik',
    kategori: 'ATK',
    stok: 80,
  ),
  AssetStockItem(
    id: 'A008',
    namaBarang: 'Meja Lipat',
    kategori: 'Furniture',
    stok: 5,
  ),
];

const _kategoriList = ['Elektronik', 'ATK', 'Furniture', 'Lainnya'];

// ═════════════════════════════════════════════════════════════════════════════
class AssetStockManagementScreen extends StatefulWidget {
  final String userId;
  const AssetStockManagementScreen({super.key, required this.userId});

  @override
  State<AssetStockManagementScreen> createState() =>
      _AssetStockManagementScreenState();
}

class _AssetStockManagementScreenState
    extends State<AssetStockManagementScreen> {
  final List<AssetStockItem> _items = List.of(_dummyStock);
  bool _isLoading = false;
  String _searchQuery = '';
  String? _filterKategori;

  List<AssetStockItem> get _filtered {
    var list = _items;
    if (_filterKategori != null) {
      list = list.where((i) => i.kategori == _filterKategori).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list
          .where(
            (i) =>
                i.namaBarang.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    return list;
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoading = false);
  }

  void _openAddEditForm({AssetStockItem? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StockItemForm(
        existing: existing,
        onSaved: (item) {
          setState(() {
            if (existing != null) {
              final idx = _items.indexWhere((i) => i.id == existing.id);
              if (idx != -1) _items[idx] = item;
            } else {
              _items.add(item);
            }
          });
          _snack(
            existing != null
                ? 'Barang berhasil diupdate'
                : 'Barang baru berhasil ditambahkan',
          );
        },
      ),
    );
  }

  Future<void> _deleteItem(AssetStockItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Barang'),
        content: Text(
          'Hapus "${item.namaBarang}" dari daftar stok?\nTindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _items.removeWhere((i) => i.id == item.id));
    _snack('Barang berhasil dihapus');
  }

  void _toggleAktif(AssetStockItem item) {
    setState(() => item.aktif = !item.aktif);
    _snack(item.aktif ? 'Barang diaktifkan' : 'Barang dinonaktifkan');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFF10B981),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Manajemen Stok Barang',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.black87,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black87, size: 18),
              onPressed: _load,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditForm(),
        backgroundColor: const Color(0xFF607D8B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tambah Barang',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildStockCard(_filtered[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari nama barang...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('Semua', null),
                ..._kategoriList.map((k) => _filterChip(k, k)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _filterKategori == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filterKategori = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF607D8B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockCard(AssetStockItem item) {
    final lowStock = item.stok <= 5;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF607D8B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.kategori == 'Elektronik'
                        ? Icons.devices_rounded
                        : item.kategori == 'ATK'
                        ? Icons.edit_note_rounded
                        : item.kategori == 'Furniture'
                        ? Icons.chair_rounded
                        : Icons.category_rounded,
                    color: const Color(0xFF607D8B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.namaBarang,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          if (!item.aktif)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Nonaktif',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.kategori,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      if (item.deskripsi?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.deskripsi!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: lowStock ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: lowStock ? Colors.red[200]! : Colors.green[200]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 12,
                        color: lowStock ? Colors.red[700] : Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Stok: ${item.stok}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: lowStock ? Colors.red[700] : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    item.aktif
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    color: item.aktif
                        ? const Color(0xFF10B981)
                        : Colors.grey[400],
                    size: 28,
                  ),
                  onPressed: () => _toggleAktif(item),
                  tooltip: item.aktif ? 'Nonaktifkan' : 'Aktifkan',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: Color(0xFF607D8B),
                  ),
                  onPressed: () => _openAddEditForm(existing: item),
                  tooltip: 'Edit',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: Colors.red[400],
                  ),
                  onPressed: () => _deleteItem(item),
                  tooltip: 'Hapus',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Barang',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tambahkan barang via tombol "Tambah Barang"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    ),
  );
}

// ── Bottom Sheet Form Tambah/Edit Barang ────────────────────────────────────
class _StockItemForm extends StatefulWidget {
  final AssetStockItem? existing;
  final void Function(AssetStockItem item) onSaved;

  const _StockItemForm({this.existing, required this.onSaved});

  @override
  State<_StockItemForm> createState() => _StockItemFormState();
}

class _StockItemFormState extends State<_StockItemForm> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _stokCtrl;
  late final TextEditingController _deskripsiCtrl;
  String _kategori = _kategoriList.first;
  bool _isSaving = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.existing?.namaBarang ?? '');
    _stokCtrl = TextEditingController(
      text: widget.existing?.stok.toString() ?? '',
    );
    _deskripsiCtrl = TextEditingController(
      text: widget.existing?.deskripsi ?? '',
    );
    _kategori = widget.existing?.kategori ?? _kategoriList.first;
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _stokCtrl.dispose();
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nama = _namaCtrl.text.trim();
    final stokStr = _stokCtrl.text.trim();

    if (nama.isEmpty) {
      _snack('Nama barang wajib diisi');
      return;
    }
    final stok = int.tryParse(stokStr);
    if (stok == null || stok < 0) {
      _snack('Jumlah stok tidak valid');
      return;
    }

    setState(() => _isSaving = true);

    await Future.delayed(const Duration(milliseconds: 600));

    final item = AssetStockItem(
      id: widget.existing?.id ?? 'A${DateTime.now().millisecondsSinceEpoch}',
      namaBarang: nama,
      kategori: _kategori,
      stok: stok,
      deskripsi: _deskripsiCtrl.text.trim().isEmpty
          ? null
          : _deskripsiCtrl.text.trim(),
      aktif: widget.existing?.aktif ?? true,
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved(item);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                isEdit ? 'Edit Barang' : 'Tambah Barang Baru',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nama Barang',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _namaCtrl,
                      decoration: _inputDecoration(
                        'Contoh: Laptop Lenovo ThinkPad',
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Kategori',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _kategori,
                      decoration: _inputDecoration(null),
                      items: _kategoriList
                          .map(
                            (k) => DropdownMenuItem(
                              value: k,
                              child: Text(
                                k,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _kategori = v ?? _kategori),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Jumlah Stok',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _stokCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Contoh: 10'),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Deskripsi (opsional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _deskripsiCtrl,
                      maxLines: 2,
                      decoration: _inputDecoration('Contoh: i5, 16GB RAM'),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF607D8B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          isEdit ? 'Simpan Perubahan' : 'Tambah Barang',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.all(12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF607D8B), width: 1.5),
    ),
  );
}
