// Services/inventory_service.dart — NEW FILE
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'token_service.dart';

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  const ApiResponse({required this.success, required this.message, this.data});
}

class InventoryItemModel {
  final int id;
  final String kodeAset;
  final String namaBarang;
  final String kategori;
  final String? merk;
  final String? serialNumber;
  final String? spesifikasi;
  final String kondisi;
  final int officeLocationId;
  final String? officeName;
  final DateTime? tanggalPembelian;
  final double? hargaBeli;
  final String? gambarPath;
  final String? gambarFileName;
  final String status; // Tersedia | Dipinjam | Rusak | Hilang
  final String? penanggungJawabUserId;
  final String? penanggungJawabName;
  final String? penanggungJawabJob;
  final String? adminInventarisUserId;
  final String? adminInventarisName;
  final DateTime? tanggalSerahTerima;
  final bool aktif;

  const InventoryItemModel({
    required this.id,
    required this.kodeAset,
    required this.namaBarang,
    required this.kategori,
    this.merk,
    this.serialNumber,
    this.spesifikasi,
    required this.kondisi,
    required this.officeLocationId,
    this.officeName,
    this.tanggalPembelian,
    this.hargaBeli,
    this.gambarPath,
    this.gambarFileName,
    required this.status,
    this.penanggungJawabUserId,
    this.penanggungJawabName,
    this.penanggungJawabJob,
    this.adminInventarisUserId,
    this.adminInventarisName,
    this.tanggalSerahTerima,
    required this.aktif,
  });

  bool get hasGambar => gambarPath != null && gambarPath!.isNotEmpty;
  bool get tersedia => status == 'Tersedia';
  bool get dipinjam => status == 'Dipinjam';

  Color get statusColor {
    switch (status) {
      case 'Tersedia':
        return const Color(0xFF10B981);
      case 'Dipinjam':
        return const Color(0xFF6366F1);
      case 'Rusak':
        return const Color(0xFFF59E0B);
      case 'Hilang':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  IconData get kategoriIcon {
    final k = kategori.toLowerCase();
    if (k.contains('laptop') || k.contains('komputer')) {
      return Icons.laptop_mac_rounded;
    }
    if (k.contains('printer')) return Icons.print_rounded;
    if (k.contains('mouse')) return Icons.mouse_rounded;
    if (k.contains('monitor')) return Icons.desktop_windows_rounded;
    if (k.contains('hp') || k.contains('phone') || k.contains('handphone')) {
      return Icons.smartphone_rounded;
    }
    if (k.contains('kamera') || k.contains('camera')) {
      return Icons.camera_alt_rounded;
    }
    return Icons.devices_other_rounded;
  }

  factory InventoryItemModel.fromJson(
    Map<String, dynamic> j,
  ) => InventoryItemModel(
    id: ((j['Id'] ?? j['id'] ?? 0) as num).toInt(),
    kodeAset: (j['KodeAset'] ?? j['kodeAset'] ?? '').toString(),
    namaBarang: (j['NamaBarang'] ?? j['namaBarang'] ?? '').toString(),
    kategori: (j['Kategori'] ?? j['kategori'] ?? '').toString(),
    merk: (j['Merk'] ?? j['merk'])?.toString(),
    serialNumber: (j['SerialNumber'] ?? j['serialNumber'])?.toString(),
    spesifikasi: (j['Spesifikasi'] ?? j['spesifikasi'])?.toString(),
    kondisi: (j['Kondisi'] ?? j['kondisi'] ?? 'Baik').toString(),
    officeLocationId:
        ((j['OfficeLocationId'] ?? j['officeLocationId'] ?? 0) as num).toInt(),
    officeName: (j['OfficeName'] ?? j['officeName'])?.toString(),
    tanggalPembelian: (j['TanggalPembelian'] ?? j['tanggalPembelian']) != null
        ? DateTime.tryParse(
            (j['TanggalPembelian'] ?? j['tanggalPembelian']).toString(),
          )
        : null,
    hargaBeli: (j['HargaBeli'] ?? j['hargaBeli']) == null
        ? null
        : ((j['HargaBeli'] ?? j['hargaBeli']) as num).toDouble(),
    gambarPath: (j['GambarPath'] ?? j['gambarPath'])?.toString(),
    gambarFileName: (j['GambarFileName'] ?? j['gambarFileName'])?.toString(),
    status: (j['Status'] ?? j['status'] ?? 'Tersedia').toString(),
    penanggungJawabUserId:
        (j['PenanggungJawabUserId'] ?? j['penanggungJawabUserId'])?.toString(),
    penanggungJawabName: (j['PenanggungJawabName'] ?? j['penanggungJawabName'])
        ?.toString(),
    penanggungJawabJob: (j['PenanggungJawabJob'] ?? j['penanggungJawabJob'])
        ?.toString(),
    adminInventarisUserId:
        (j['AdminInventarisUserId'] ?? j['adminInventarisUserId'])?.toString(),
    adminInventarisName: (j['AdminInventarisName'] ?? j['adminInventarisName'])
        ?.toString(),
    tanggalSerahTerima:
        (j['TanggalSerahTerima'] ?? j['tanggalSerahTerima']) != null
        ? DateTime.tryParse(
            (j['TanggalSerahTerima'] ?? j['tanggalSerahTerima']).toString(),
          )
        : null,
    aktif: (j['Aktif'] ?? j['aktif'] ?? true) == true,
  );
}

class InventoryHandoverLogModel {
  final int id;
  final String aksi;
  final String? catatan;
  final DateTime tanggal;
  final String? penanggungJawabUserId;
  final String? penanggungJawabName;
  final String? adminInventarisUserId;
  final String? adminInventarisName;
  final String createdBy;
  final String? createdByName;

  const InventoryHandoverLogModel({
    required this.id,
    required this.aksi,
    this.catatan,
    required this.tanggal,
    this.penanggungJawabUserId,
    this.penanggungJawabName,
    this.adminInventarisUserId,
    this.adminInventarisName,
    required this.createdBy,
    this.createdByName,
  });

  factory InventoryHandoverLogModel.fromJson(
    Map<String, dynamic> j,
  ) => InventoryHandoverLogModel(
    id: ((j['Id'] ?? j['id'] ?? 0) as num).toInt(),
    aksi: (j['Aksi'] ?? j['aksi'] ?? '').toString(),
    catatan: (j['Catatan'] ?? j['catatan'])?.toString(),
    tanggal:
        DateTime.tryParse((j['Tanggal'] ?? j['tanggal'] ?? '').toString()) ??
        DateTime.now(),
    penanggungJawabUserId:
        (j['PenanggungJawabUserId'] ?? j['penanggungJawabUserId'])?.toString(),
    penanggungJawabName: (j['PenanggungJawabName'] ?? j['penanggungJawabName'])
        ?.toString(),
    adminInventarisUserId:
        (j['AdminInventarisUserId'] ?? j['adminInventarisUserId'])?.toString(),
    adminInventarisName: (j['AdminInventarisName'] ?? j['adminInventarisName'])
        ?.toString(),
    createdBy: (j['CreatedBy'] ?? j['createdBy'] ?? '').toString(),
    createdByName: (j['CreatedByName'] ?? j['createdByName'])?.toString(),
  );
}

class InventoryEligibleUserModel {
  final String userId;
  final String name;
  final String? jobPosition;
  final String? organization;

  const InventoryEligibleUserModel({
    required this.userId,
    required this.name,
    this.jobPosition,
    this.organization,
  });

  factory InventoryEligibleUserModel.fromJson(Map<String, dynamic> j) =>
      InventoryEligibleUserModel(
        userId: (j['UserId'] ?? j['userId'] ?? '').toString(),
        name: (j['Name'] ?? j['name'] ?? '').toString(),
        jobPosition: (j['JobPosition'] ?? j['jobPosition'])?.toString(),
        organization: (j['Organization'] ?? j['organization'])?.toString(),
      );
}

class InventoryService {
  static const String _base = '/api/inventory';

  static Future<Map<String, String>> _jsonHeaders() async =>
      TokenService.jsonHeaders();
  static Future<Map<String, String>> _multipartHeaders() async =>
      TokenService.multipartHeaders();

  static dynamic _get(Map<String, dynamic> body, String key) {
    if (body.containsKey(key)) return body[key];
    final lower = key[0].toLowerCase() + key.substring(1);
    if (body.containsKey(lower)) return body[lower];
    final pascal = key[0].toUpperCase() + key.substring(1);
    if (body.containsKey(pascal)) return body[pascal];
    return null;
  }

  static Future<bool> isHeadHrd({required String userId}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/is-head-hrd'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
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
      TokenService.invalidate();
      return _sendMultipart(url, fields, buildFiles, isRetry: true);
    }
    return res;
  }

  static Future<ApiResponse<int>> createItem({
    required String userId,
    required String kodeAset,
    required String namaBarang,
    required String kategori,
    required int officeLocationId,
    String? merk,
    String? serialNumber,
    String? spesifikasi,
    String kondisi = 'Baik',
    DateTime? tanggalPembelian,
    double? hargaBeli,
    Uint8List? gambarBytes,
    String? gambarFileName,
  }) async {
    try {
      final url = Uri.parse('$baseURL$_base/item-create');
      final fields = <String, String>{
        'userId': userId,
        'kodeAset': kodeAset,
        'namaBarang': namaBarang,
        'kategori': kategori,
        'officeLocationId': officeLocationId.toString(),
        'kondisi': kondisi,
        if (merk != null) 'merk': merk,
        if (serialNumber != null) 'serialNumber': serialNumber,
        if (spesifikasi != null) 'spesifikasi': spesifikasi,
        if (tanggalPembelian != null)
          'tanggalPembelian': tanggalPembelian.toIso8601String(),
        if (hargaBeli != null) 'hargaBeli': hargaBeli.toString(),
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
        return const ApiResponse(
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

  static Future<ApiResponse<void>> updateItem({
    required int id,
    required String userId,
    required String kodeAset,
    required String namaBarang,
    required String kategori,
    required int officeLocationId,
    String? merk,
    String? serialNumber,
    String? spesifikasi,
    String kondisi = 'Baik',
    DateTime? tanggalPembelian,
    double? hargaBeli,
    bool gantiGambar = false,
    Uint8List? gambarBytes,
    String? gambarFileName,
  }) async {
    try {
      final url = Uri.parse('$baseURL$_base/item-update');
      final fields = <String, String>{
        'id': id.toString(),
        'userId': userId,
        'kodeAset': kodeAset,
        'namaBarang': namaBarang,
        'kategori': kategori,
        'officeLocationId': officeLocationId.toString(),
        'kondisi': kondisi,
        'gantiGambar': gantiGambar.toString(),
        if (merk != null) 'merk': merk,
        if (serialNumber != null) 'serialNumber': serialNumber,
        if (spesifikasi != null) 'spesifikasi': spesifikasi,
        if (tanggalPembelian != null)
          'tanggalPembelian': tanggalPembelian.toIso8601String(),
        if (hargaBeli != null) 'hargaBeli': hargaBeli.toString(),
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
        return const ApiResponse(
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

  static Future<ApiResponse<void>> deleteItem({
    required int id,
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/item-delete'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'inventoryItemId': id, 'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;
      return ApiResponse(success: success, message: message);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<List<InventoryItemModel>>> getAllItems({
    required String userId,
    int? officeLocationId,
    String? status,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/item-list-all'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'userId': userId,
          'officeLocationId': officeLocationId,
          'status': status,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<InventoryItemModel> items = [];
      final data = _get(body, 'data');
      if (data is Map && data['items'] is List) {
        items = (data['items'] as List)
            .map((e) => InventoryItemModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<List<int>>> getItemImage({required int id}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/item-image'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'inventoryItemId': id}),
      );
      if (res.statusCode == 200) {
        return ApiResponse(success: true, message: 'OK', data: res.bodyBytes);
      }
      return const ApiResponse(
        success: false,
        message: 'Gambar tidak ditemukan',
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<void>> assign({
    required int inventoryItemId,
    required String penanggungJawabUserId,
    required String adminInventarisUserId,
    String? catatan,
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/assign'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'inventoryItemId': inventoryItemId,
          'penanggungJawabUserId': penanggungJawabUserId,
          'adminInventarisUserId': adminInventarisUserId,
          'catatan': catatan,
          'userId': userId,
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

  /// List user dengan organization mengandung 'Inventaris' — dropdown
  /// pilih Admin Inventaris saat assign barang.
  static Future<ApiResponse<List<InventoryEligibleUserModel>>>
  getEligibleAdminInventaris({required String userId}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/eligible-admin-inventaris'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<InventoryEligibleUserModel> items = [];
      final data = _get(body, 'data');
      if (data is Map && data['users'] is List) {
        items = (data['users'] as List)
            .map(
              (e) => InventoryEligibleUserModel.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList();
      }
      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<void>> returnItem({
    required int inventoryItemId,
    String? catatan,
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/return'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'inventoryItemId': inventoryItemId,
          'catatan': catatan,
          'userId': userId,
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

  static Future<ApiResponse<void>> markCondition({
    required int inventoryItemId,
    required String kondisiBaru,
    String? catatan,
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/mark-condition'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'inventoryItemId': inventoryItemId,
          'kondisiBaru': kondisiBaru,
          'catatan': catatan,
          'userId': userId,
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

  static Future<ApiResponse<List<InventoryHandoverLogModel>>> getHandoverLog({
    required int inventoryItemId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/handover-log'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'inventoryItemId': inventoryItemId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<InventoryHandoverLogModel> items = [];
      final data = _get(body, 'data');
      if (data is Map && data['items'] is List) {
        items = (data['items'] as List)
            .map(
              (e) =>
                  InventoryHandoverLogModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  /// Generate & download Berita Acara Serah Terima (PDF, 3 TTD: Penanggung
  /// Jawab + Admin Inventaris + Head HRD) untuk barang yang sedang Dipinjam.
  static Future<ApiResponse<List<int>>> generateHandoverDoc({
    required int inventoryItemId,
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/handover-generate'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'inventoryItemId': inventoryItemId,
          'userId': userId,
        }),
      );
      if (res.statusCode == 200) {
        return ApiResponse(success: true, message: 'OK', data: res.bodyBytes);
      }
      String msg = 'Gagal membuat dokumen';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        msg = (_get(body, 'message') ?? msg) as String;
      } catch (_) {}
      return ApiResponse(success: false, message: msg);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<List<InventoryEligibleUserModel>>>
  getAllActiveEmployees({required String userId}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/eligible-head-inventaris'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      List<InventoryEligibleUserModel> items = [];
      final data = _get(body, 'data');
      if (data is Map && data['users'] is List) {
        items = (data['users'] as List)
            .map(
              (e) => InventoryEligibleUserModel.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList();
      }
      return ApiResponse(success: success, message: message, data: items);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<InventoryEligibleUserModel>>
  getAutoAdminInventaris({
    required String userId,
    required String kategori,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/auto-admin-inventaris'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId, 'kategori': kategori}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = (_get(body, 'success') ?? false) == true;
      final message = (_get(body, 'message') ?? '') as String;

      InventoryEligibleUserModel? admin;
      final data = _get(body, 'data');
      if (data is Map) {
        admin = InventoryEligibleUserModel.fromJson(
          Map<String, dynamic>.from(data),
        );
      }

      return ApiResponse(success: success, message: message, data: admin);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }
}
