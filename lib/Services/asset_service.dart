// Services/asset_service.dart — NEW FILE
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/token_service.dart';

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  const ApiResponse({required this.success, required this.message, this.data});
}

// ── MODELS ───────────────────────────────────────────────────────────────────
class AssetOfficeModel {
  final int id;
  final String officeName;
  final double? latitude;
  final double? longitude;

  const AssetOfficeModel({
    required this.id,
    required this.officeName,
    this.latitude,
    this.longitude,
  });

  factory AssetOfficeModel.fromJson(Map<String, dynamic> j) => AssetOfficeModel(
    id: ((j['Id'] ?? j['id'] ?? 0) as num).toInt(),
    officeName: (j['OfficeName'] ?? j['officeName'] ?? '').toString(),
    latitude: (j['Latitude'] ?? j['latitude']) == null
        ? null
        : ((j['Latitude'] ?? j['latitude']) as num).toDouble(),
    longitude: (j['Longitude'] ?? j['longitude']) == null
        ? null
        : ((j['Longitude'] ?? j['longitude']) as num).toDouble(),
  );
}

class AssetReportPeriodModel {
  final int id;
  final int tahun;
  final int bulan;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String? keterangan;

  const AssetReportPeriodModel({
    required this.id,
    required this.tahun,
    required this.bulan,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.keterangan,
  });

  static const _bulanNama = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  String get label => '${_bulanNama[bulan]} $tahun';

  factory AssetReportPeriodModel.fromJson(Map<String, dynamic> j) =>
      AssetReportPeriodModel(
        id: ((j['Id'] ?? j['id'] ?? 0) as num).toInt(),
        tahun: ((j['Tahun'] ?? j['tahun'] ?? 0) as num).toInt(),
        bulan: ((j['Bulan'] ?? j['bulan'] ?? 0) as num).toInt(),
        tanggalMulai:
            DateTime.tryParse(
              (j['TanggalMulai'] ?? j['tanggalMulai'] ?? '').toString(),
            ) ??
            DateTime.now(),
        tanggalSelesai:
            DateTime.tryParse(
              (j['TanggalSelesai'] ?? j['tanggalSelesai'] ?? '').toString(),
            ) ??
            DateTime.now(),
        keterangan: (j['Keterangan'] ?? j['keterangan'])?.toString(),
      );
}

class AssetReportEmployeeModel {
  final String userId;
  final String name;
  final String? jobPosition;
  final int jumlahTransaksi;

  const AssetReportEmployeeModel({
    required this.userId,
    required this.name,
    this.jobPosition,
    required this.jumlahTransaksi,
  });

  factory AssetReportEmployeeModel.fromJson(Map<String, dynamic> j) =>
      AssetReportEmployeeModel(
        userId: (j['UserId'] ?? j['userId'] ?? '').toString(),
        name: (j['Name'] ?? j['name'] ?? '').toString(),
        jobPosition: (j['JobPosition'] ?? j['jobPosition'])?.toString(),
        jumlahTransaksi:
            ((j['JumlahTransaksi'] ?? j['jumlahTransaksi'] ?? 0) as num)
                .toInt(),
      );
}

class AssetItemModel {
  final int id;
  final String namaBarang;
  final String kategori;
  final int? kategoriId;
  final String? iconKey;
  final String? warnaHex;
  final int? officeLocationId;
  final String? officeName;
  final String? deskripsi;
  final int stok;
  final String? gambarPath;
  final String? gambarFileName;
  final bool aktif;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  const AssetItemModel({
    required this.id,
    required this.namaBarang,
    required this.kategori,
    this.kategoriId,
    this.iconKey,
    this.warnaHex,
    this.officeLocationId,
    this.officeName,
    this.deskripsi,
    required this.stok,
    this.gambarPath,
    this.gambarFileName,
    required this.aktif,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  bool get hasGambar => gambarPath != null && gambarPath!.isNotEmpty;

  Color get categoryColor {
    try {
      final hex = (warnaHex ?? '#607D8B').replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF607D8B);
    }
  }

  IconData get categoryIcon {
    switch (iconKey) {
      case 'devices':
        return Icons.devices_rounded;
      case 'edit_note':
        return Icons.edit_note_rounded;
      case 'chair':
        return Icons.chair_rounded;
      case 'computer':
        return Icons.computer_rounded;
      case 'print':
        return Icons.print_rounded;
      case 'tools':
        return Icons.build_rounded;
      case 'vehicle':
        return Icons.directions_car_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'category':
      default:
        return Icons.category_rounded;
    }
  }

  factory AssetItemModel.fromJson(Map<String, dynamic> j) => AssetItemModel(
    id: ((j['Id'] ?? j['id'] ?? 0) as num).toInt(),
    namaBarang: (j['NamaBarang'] ?? j['namaBarang'] ?? j['nama_barang'] ?? '')
        .toString(),
    kategori: (j['Kategori'] ?? j['kategori'] ?? '').toString(),
    kategoriId: (j['KategoriId'] ?? j['kategoriId']) == null
        ? null
        : ((j['KategoriId'] ?? j['kategoriId']) as num).toInt(),
    iconKey: (j['IconKey'] ?? j['iconKey'])?.toString(),
    warnaHex: (j['WarnaHex'] ?? j['warnaHex'])?.toString(),
    officeLocationId: (j['OfficeLocationId'] ?? j['officeLocationId']) == null
        ? null
        : ((j['OfficeLocationId'] ?? j['officeLocationId']) as num).toInt(),
    officeName: (j['OfficeName'] ?? j['officeName'])?.toString(),
    deskripsi: (j['Deskripsi'] ?? j['deskripsi'])?.toString(),
    stok: ((j['Stok'] ?? j['stok'] ?? 0) as num).toInt(),
    gambarPath: (j['GambarPath'] ?? j['gambarPath'] ?? j['gambar_path'])
        ?.toString(),
    gambarFileName:
        (j['GambarFileName'] ?? j['gambarFileName'] ?? j['gambar_filename'])
            ?.toString(),
    aktif: (j['Aktif'] ?? j['aktif'] ?? true) as bool,
    createdBy: (j['CreatedBy'] ?? j['createdBy'])?.toString(),
    createdAt: _parseDate(j['CreatedAt'] ?? j['createdAt']),
    updatedBy: (j['UpdatedBy'] ?? j['updatedBy'])?.toString(),
    updatedAt: _parseDate(j['UpdatedAt'] ?? j['updatedAt']),
  );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

class AssetCategoryModel {
  final int id;
  final String namaKategori;
  final String iconKey;
  final String warnaHex;
  final int urutan;

  const AssetCategoryModel({
    required this.id,
    required this.namaKategori,
    required this.iconKey,
    required this.warnaHex,
    required this.urutan,
  });

  Color get color {
    try {
      final hex = warnaHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF607D8B);
    }
  }

  IconData get icon {
    switch (iconKey) {
      case 'devices':
        return Icons.devices_rounded;
      case 'edit_note':
        return Icons.edit_note_rounded;
      case 'chair':
        return Icons.chair_rounded;
      case 'computer':
        return Icons.computer_rounded;
      case 'print':
        return Icons.print_rounded;
      case 'tools':
        return Icons.build_rounded;
      case 'vehicle':
        return Icons.directions_car_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'category':
      default:
        return Icons.category_rounded;
    }
  }

  factory AssetCategoryModel.fromJson(Map<String, dynamic> j) =>
      AssetCategoryModel(
        id: ((j['Id'] ?? j['id'] ?? 0) as num).toInt(),
        namaKategori: (j['NamaKategori'] ?? j['namaKategori'] ?? '').toString(),
        iconKey: (j['IconKey'] ?? j['iconKey'] ?? 'category').toString(),
        warnaHex: (j['WarnaHex'] ?? j['warnaHex'] ?? '#607D8B').toString(),
        urutan: ((j['Urutan'] ?? j['urutan'] ?? 0) as num).toInt(),
      );
}

class AssetRequestModel {
  final int id;
  final int assetItemId;
  final String namaBarang;
  final String? userId;
  final String? userName;
  final String? userJob;
  final String kategori; // "dipinjam" | "diambil"
  final int jumlah;
  final String? catatan;
  final String status; // Pending | Approved | Rejected | Dikembalikan
  final String? rejectionReason;
  final DateTime tanggalPengajuan;
  final DateTime? approvedAt;
  final DateTime? tanggalKembali;
  final int stokTersedia;
  final int daysWaiting;

  const AssetRequestModel({
    required this.id,
    required this.assetItemId,
    required this.namaBarang,
    this.userId,
    this.userName,
    this.userJob,
    required this.kategori,
    required this.jumlah,
    this.catatan,
    required this.status,
    this.rejectionReason,
    required this.tanggalPengajuan,
    this.approvedAt,
    this.tanggalKembali,
    this.stokTersedia = 0,
    this.daysWaiting = 0,
  });

  factory AssetRequestModel.fromJson(
    Map<String, dynamic> j,
  ) => AssetRequestModel(
    id: ((j['Id'] ?? j['id'] ?? 0) as num).toInt(),
    assetItemId: ((j['AssetItemId'] ?? j['assetItemId'] ?? 0) as num).toInt(),
    namaBarang: (j['NamaBarang'] ?? j['namaBarang'] ?? '').toString(),
    userId: (j['UserId'] ?? j['userId'])?.toString(),
    userName: (j['UserName'] ?? j['userName'])?.toString(),
    userJob: (j['UserJob'] ?? j['userJob'])?.toString(),
    kategori: (j['Kategori'] ?? j['kategori'] ?? '').toString(),
    jumlah: ((j['Jumlah'] ?? j['jumlah'] ?? 0) as num).toInt(),
    catatan: (j['Catatan'] ?? j['catatan'])?.toString(),
    status: (j['Status'] ?? j['status'] ?? 'Pending').toString(),
    rejectionReason: (j['RejectionReason'] ?? j['rejectionReason'])?.toString(),
    tanggalPengajuan:
        _parseDate(j['CreatedAt'] ?? j['createdAt'] ?? j['tanggalPengajuan']) ??
        DateTime.now(),
    approvedAt: _parseDate(j['ApprovedAt'] ?? j['approvedAt']),
    tanggalKembali: _parseDate(j['TanggalKembali'] ?? j['tanggalKembali']),
    stokTersedia: ((j['StokTersedia'] ?? j['stokTersedia'] ?? 0) as num)
        .toInt(),
    daysWaiting: ((j['DaysWaiting'] ?? j['daysWaiting'] ?? 0) as num).toInt(),
  );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

// ── SERVICE ──────────────────────────────────────────────────────────────────
class AssetService {
  static Future<http.Response> _post(
    String endpoint,
    Map<String, dynamic> payload,
  ) {
    return TokenService.authorizedPost(
      Uri.parse('$baseURL$_base/$endpoint'),
      body: jsonEncode(payload),
    );
  }

  static const String _base = '/api/asset';

  /// Panggil sekali sebelum melakukan banyak request paralel, supaya
  /// token sudah ter-cache dan tidak ada race condition saat beberapa
  /// request memanggil TokenService.getToken() bersamaan pada kondisi
  /// cache masih kosong.
  static Future<void> warmUpToken() async {
    await TokenService.getToken();
  }

  static Future<Map<String, String>> _jsonHeaders() async {
    return TokenService.jsonHeaders();
  }

  static Future<Map<String, String>> _multipartHeaders() async {
    return TokenService.multipartHeaders();
  }

  static dynamic _get(Map<String, dynamic> body, String key) {
    if (body.containsKey(key)) return body[key];
    final lower = key[0].toLowerCase() + key.substring(1);
    if (body.containsKey(lower)) return body[lower];
    final pascal = key[0].toUpperCase() + key.substring(1);
    if (body.containsKey(pascal)) return body[pascal];
    return null;
  }

  /// Cek apakah user adalah Head HRD spesifik (untuk akses tab Laporan,
  /// beda dengan canManageStock yang berlaku untuk semua staff HRD).
  static Future<bool> isHeadHrd({required String userId}) async {
    try {
      final res = await _post('is-head-hrd', {'userId': userId});

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final success = (_get(body, 'success') ?? false) == true;
        final isHead = (_get(body, 'isHeadHrd') ?? false) == true;

        return success && isHead;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah user boleh Kelola Stok (siapa saja tim HRD, tidak harus Head).
  /// Sama pola dengan DoaService.canInputDoa.
  static Future<bool> canManageStock({required String userId}) async {
    try {
      final res = await _post('can-manage-stock', {'userId': userId});

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final success = (_get(body, 'success') ?? false) == true;
        final canManage = (_get(body, 'canManage') ?? false) == true;

        return success && canManage;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // =====================================================================
  // ── ITEM CRUD ──────────────────────────────────────────────────────
  // =====================================================================

  /// Helper: kirim multipart request dengan retry sekali kalau 401.
  /// [buildFiles] adalah factory function, dipanggil ULANG setiap
  /// percobaan — karena http.MultipartFile tidak bisa dipakai dua kali
  /// setelah stream-nya terkonsumsi oleh request pertama.
  static Future<http.Response> _sendMultipart(
    Uri url,
    Map<String, String> fields,
    List<http.MultipartFile> Function() buildFiles, {
    bool isRetry = false,
  }) async {
    final mr = http.MultipartRequest('POST', url);
    mr.headers.addAll(await _multipartHeaders());
    mr.fields.addAll(fields);
    mr.files.addAll(buildFiles());

    final streamed = await mr.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 401 && !isRetry) {
      // Token expired di server — invalidate cache lalu coba sekali lagi
      // dengan token baru DAN file yang dibangun ulang dari bytes asli.
      TokenService.invalidate();
      return _sendMultipart(url, fields, buildFiles, isRetry: true);
    }

    return res;
  }

  /// Tambah barang baru. [gambarBytes]/[gambarFileName] opsional.
  static Future<ApiResponse<int>> createItem({
    required String userId,
    required String namaBarang,
    required int kategoriId,
    required int officeLocationId,
    String? deskripsi,
    required int stok,
    Uint8List? gambarBytes,
    String? gambarFileName,
  }) async {
    try {
      final url = Uri.parse('$baseURL$_base/item-create');

      final fields = <String, String>{
        'userId': userId,
        'namaBarang': namaBarang,
        'kategoriId': kategoriId.toString(),
        'officeLocationId': officeLocationId.toString(),
        'stok': stok.toString(),
        if (deskripsi != null) 'deskripsi': deskripsi,
      };

      List<http.MultipartFile> buildFiles() {
        if (gambarBytes != null && gambarBytes.isNotEmpty) {
          return [
            http.MultipartFile.fromBytes(
              'gambar',
              gambarBytes,
              filename: gambarFileName ?? 'gambar.jpg',
            ),
          ];
        }
        return [];
      }

      final res = await _sendMultipart(url, fields, buildFiles);

      if (res.statusCode == 401) {
        return ApiResponse(
          success: false,
          message: 'Sesi login berakhir. Silakan login ulang.',
        );
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;
      int? id;
      final data = _get(body, 'data');
      if (data is Map) id = (data['id'] as num?)?.toInt();

      return ApiResponse(success: success, message: message, data: id);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Update barang. [gantiGambar]=true untuk ganti/hapus gambar.
  /// Kalau [gantiGambar]=true dan [gambarBytes]=null → gambar lama dihapus.
  static Future<ApiResponse<void>> updateItem({
    required int id,
    required String userId,
    required String namaBarang,
    required int kategoriId,
    required int officeLocationId,
    String? deskripsi,
    required int stok,
    bool gantiGambar = false,
    Uint8List? gambarBytes,
    String? gambarFileName,
  }) async {
    try {
      final url = Uri.parse('$baseURL$_base/item-update');

      final fields = <String, String>{
        'id': id.toString(),
        'userId': userId,
        'namaBarang': namaBarang,
        'kategoriId': kategoriId.toString(),
        'officeLocationId': officeLocationId.toString(),
        'stok': stok.toString(),
        'gantiGambar': gantiGambar.toString(),
        if (deskripsi != null) 'deskripsi': deskripsi,
      };

      List<http.MultipartFile> buildFiles() {
        if (gantiGambar && gambarBytes != null && gambarBytes.isNotEmpty) {
          return [
            http.MultipartFile.fromBytes(
              'gambar',
              gambarBytes,
              filename: gambarFileName ?? 'gambar.jpg',
            ),
          ];
        }
        return [];
      }

      final res = await _sendMultipart(url, fields, buildFiles);

      if (res.statusCode == 401) {
        return ApiResponse(
          success: false,
          message: 'Sesi login berakhir. Silakan login ulang.',
        );
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      return ApiResponse(success: success, message: message);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<bool>> toggleItemAktif({
    required int id,
    required String userId,
  }) async {
    try {
      final res = await _post('item-toggle-aktif', {
        'id': id,
        'userId': userId,
      });

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      bool? aktif;
      final data = _get(body, 'data');

      if (data is Map) {
        aktif = data['aktif'] as bool?;
      }

      return ApiResponse(success: success, message: message, data: aktif);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<void>> deleteItem({
    required int id,
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/item-delete'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'id': id, 'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      return ApiResponse(success: success, message: message);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// List kategori aktif (untuk dropdown form & filter katalog).
  static Future<ApiResponse<List<AssetCategoryModel>>> getCategories({
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/categories'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<AssetCategoryModel> items = [];
      final data = _get(body, 'data');
      if (data is Map && data['categories'] is List) {
        items = (data['categories'] as List)
            .map((e) => AssetCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Tambah kategori baru (tim HRD).
  static Future<ApiResponse<int>> createCategory({
    required String userId,
    required String namaKategori,
    String iconKey = 'category',
    String warnaHex = '#607D8B',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/category-create'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'userId': userId,
          'namaKategori': namaKategori,
          'iconKey': iconKey,
          'warnaHex': warnaHex,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;
      int? id;
      final data = _get(body, 'data');
      if (data is Map) id = (data['id'] as num?)?.toInt();

      return ApiResponse(success: success, message: message, data: id);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Update kategori.
  static Future<ApiResponse<void>> updateCategory({
    required int id,
    required String userId,
    required String namaKategori,
    required String iconKey,
    required String warnaHex,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/category-update'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'id': id,
          'userId': userId,
          'namaKategori': namaKategori,
          'iconKey': iconKey,
          'warnaHex': warnaHex,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      return ApiResponse(success: success, message: message);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Aktif/nonaktifkan kategori.
  static Future<ApiResponse<bool>> toggleCategoryAktif({
    required int id,
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/category-toggle-aktif'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'id': id, 'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;
      bool? aktif;
      final data = _get(body, 'data');
      if (data is Map) aktif = data['aktif'] as bool?;

      return ApiResponse(success: success, message: message, data: aktif);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Katalog barang aktif (untuk tab "Katalog Barang", semua role).
  static Future<ApiResponse<List<AssetItemModel>>> getCatalog({
    required String userId,
    int? kategoriId,
    int? officeLocationId,
  }) async {
    try {
      final res = await _post('catalog', {
        'userId': userId,
        'kategoriId': kategoriId,
        'officeLocationId': officeLocationId,
      });

      if (res.statusCode == 401) {
        return const ApiResponse(
          success: false,
          message: 'Sesi tidak dapat diperbarui. Silakan login ulang.',
        );
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<AssetItemModel> items = [];
      final data = _get(body, 'data');

      if (data is Map && data['items'] is List) {
        items = (data['items'] as List)
            .map((e) => AssetItemModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Semua barang termasuk nonaktif (untuk tab "Kelola Stok", HRD only).
  static Future<ApiResponse<List<AssetItemModel>>> getAllItems({
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/item-list-all'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<AssetItemModel> items = [];
      final data = _get(body, 'data');
      if (data is Map && data['items'] is List) {
        items = (data['items'] as List)
            .map((e) => AssetItemModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Download gambar barang sebagai bytes (untuk Image.memory).
  static Future<ApiResponse<List<int>>> getItemImage({required int id}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/item-image'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'id': id}),
      );
      if (res.statusCode == 200) {
        return ApiResponse(success: true, message: 'OK', data: res.bodyBytes);
      }
      String msg = 'Gagal memuat gambar';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        msg = (_get(body, 'message') ?? msg) as String;
      } catch (_) {}
      return ApiResponse(success: false, message: msg);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  // =====================================================================
  // ── REQUEST & APPROVAL ─────────────────────────────────────────────
  // =====================================================================

  /// User ajukan pinjam/ambil barang. Auto-approve kalau pemohon = Head HRD
  /// (lihat field [ApiResponse.data] berisi map {id, autoApproved}).
  static Future<ApiResponse<Map<String, dynamic>>> createRequest({
    required String userId,
    required int assetItemId,
    required String kategori, // "dipinjam" | "diambil"
    required int jumlah,
    String? catatan,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/request-create'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'userId': userId,
          'assetItemId': assetItemId,
          'kategori': kategori,
          'jumlah': jumlah,
          'catatan': catatan,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      Map<String, dynamic> resultData = {};
      final data = _get(body, 'data');
      if (data is Map) resultData = Map<String, dynamic>.from(data);

      return ApiResponse(success: success, message: message, data: resultData);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Head HRD approve/reject pengajuan.
  static Future<ApiResponse<void>> reviewRequest({
    required int id,
    required String hrdUserId,
    required String status, // "Approved" | "Rejected"
    String? rejectionReason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/request-review'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'id': id,
          'hrdUserId': hrdUserId,
          'status': status,
          'rejectionReason': rejectionReason,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      return ApiResponse(success: success, message: message);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Head HRD konfirmasi barang "Dipinjam" sudah dikembalikan.
  static Future<ApiResponse<void>> markReturned({
    required int id,
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/request-mark-returned'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'id': id, 'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      return ApiResponse(success: success, message: message);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// List pengajuan Pending (untuk section "Persetujuan Asset" di OrgApprovalScreen).
  static Future<ApiResponse<List<AssetRequestModel>>> getPendingRequests({
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/pending-requests'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<AssetRequestModel> items = [];
      final data = _get(body, 'data');
      if (data is Map && data['items'] is List) {
        items = (data['items'] as List)
            .map((e) => AssetRequestModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Riwayat pengajuan milik user sendiri (tab "Pengajuan Saya").
  static Future<ApiResponse<List<AssetRequestModel>>> getMyRequests({
    required String userId,
  }) async {
    try {
      final res = await _post('my-requests', {'userId': userId});

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<AssetRequestModel> items = [];
      final data = _get(body, 'data');

      if (data is Map && data['items'] is List) {
        items = (data['items'] as List)
            .map((e) => AssetRequestModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  // =====================================================================
  // ── OFFICE LOCATIONS ─────────────────────────────────────────────
  // =====================================================================

  /// List kantor aktif (dropdown saat HRD tambah/edit barang & user pilih lokasi).
  static Future<ApiResponse<List<AssetOfficeModel>>> getOffices() async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/offices'),
        headers: await _jsonHeaders(),
        body: jsonEncode({}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<AssetOfficeModel> items = [];
      final data = _get(body, 'data');
      if (data is Map && data['offices'] is List) {
        items = (data['offices'] as List)
            .map((e) => AssetOfficeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  // =====================================================================
  // ── LAPORAN ASSET (per-karyawan per-periode) ───────────────────────
  // =====================================================================

  /// List WorkPeriod untuk dropdown laporan (opsional filter tahun).
  static Future<ApiResponse<List<AssetReportPeriodModel>>> getReportPeriods({
    int? tahun,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/report-periods'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'tahun': tahun}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<AssetReportPeriodModel> items = [];
      final data = _get(body, 'data');
      if (data is Map && data['periods'] is List) {
        items = (data['periods'] as List)
            .map(
              (e) => AssetReportPeriodModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }

      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// List karyawan yang punya transaksi Approved dalam periode tertentu.
  static Future<ApiResponse<List<AssetReportEmployeeModel>>>
  getReportEmployees({required int workPeriodId}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/report-employees'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'workPeriodId': workPeriodId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<AssetReportEmployeeModel> items = [];
      final data = _get(body, 'data');
      if (data is Map && data['employees'] is List) {
        items = (data['employees'] as List)
            .map(
              (e) =>
                  AssetReportEmployeeModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }

      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Generate & download laporan docx 1 karyawan dalam 1 periode.
  /// Return bytes file docx siap di-save/share.
  static Future<ApiResponse<List<int>>> generateReport({
    required String userId,
    required int workPeriodId,
    required String requestedBy,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/report-generate'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'userId': userId,
          'workPeriodId': workPeriodId,
          'requestedBy': requestedBy,
        }),
      );
      if (res.statusCode == 200) {
        return ApiResponse(success: true, message: 'OK', data: res.bodyBytes);
      }
      String msg = 'Gagal membuat laporan';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        msg = (_get(body, 'message') ?? msg) as String;
      } catch (_) {}
      return ApiResponse(success: false, message: msg);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Badge counter jumlah pengajuan Pending (khusus Head HRD).
  static Future<ApiResponse<int>> getPendingCount({
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/pending-count'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      int count = 0;
      final data = _get(body, 'data');
      if (data is Map) count = ((data['count'] ?? 0) as num).toInt();

      return ApiResponse(success: success, message: message, data: count);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }
}
