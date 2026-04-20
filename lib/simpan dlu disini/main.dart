// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Absensi GPS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}

class LocationData {
  final String name;
  final double latitude;
  final double longitude;
  final double radius;

  LocationData({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      radius: json['radius'],
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  List<LocationData> attendanceLocations = [];
  Position? currentPosition;
  String statusMessage = "Belum ada lokasi absensi yang diatur";
  bool isLoading = false;
  bool canAttend = false;
  String nearestLocation = "";
  double nearestDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSavedLocations();
    _getCurrentLocation();
  }

  // Load lokasi yang tersimpan
  Future<void> _loadSavedLocations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedLocations = prefs.getStringList('attendance_locations');

    if (savedLocations != null) {
      setState(() {
        attendanceLocations = savedLocations.map((locationStr) {
          List<String> parts = locationStr.split(',');
          return LocationData(
            name: parts[0],
            latitude: double.parse(parts[1]),
            longitude: double.parse(parts[2]),
            radius: double.parse(parts[3]),
          );
        }).toList();
      });
    }
  }

  // Simpan lokasi
  Future<void> _saveLocations() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> locationStrings = attendanceLocations.map((location) {
        return '${location.name},${location.latitude},${location.longitude},${location.radius}';
      }).toList();

      bool success = await prefs.setStringList(
        'attendance_locations',
        locationStrings,
      );
      debugPrint(
        "Save locations: $success, Count: ${attendanceLocations.length}",
      );

      // Verifikasi data tersimpan
      List<String>? saved = prefs.getStringList('attendance_locations');
      debugPrint("Verified saved locations: ${saved?.length ?? 0}");
    } catch (e) {
      debugPrint("Error saving locations: $e");
    }
  }

  // Fungsi untuk mendapatkan lokasi saat ini
  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoading = true;
      statusMessage = "Mendapatkan lokasi...";
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            statusMessage = "Permission lokasi ditolak";
            isLoading = false;
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentPosition = position;
      });

      _checkDistance();
    } catch (e) {
      setState(() {
        statusMessage = "Error: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  // Fungsi untuk menghitung jarak
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Cek jarak ke lokasi absensi
  void _checkDistance() {
    if (currentPosition == null || attendanceLocations.isEmpty) {
      setState(() {
        statusMessage = attendanceLocations.isEmpty
            ? "Belum ada lokasi absensi yang diatur"
            : "Belum mendapatkan lokasi";
        isLoading = false;
        canAttend = false;
      });
      return;
    }

    double minDistance = double.infinity;
    String closestLocation = "";
    double allowedRadius = 0;

    for (var location in attendanceLocations) {
      double distance = calculateDistance(
        currentPosition!.latitude,
        currentPosition!.longitude,
        location.latitude,
        location.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestLocation = location.name;
        allowedRadius = location.radius;
      }
    }

    setState(() {
      nearestDistance = minDistance;
      nearestLocation = closestLocation;
      canAttend = minDistance <= allowedRadius;

      if (canAttend) {
        statusMessage =
            "✅ Anda berada dalam jangkauan absensi\n"
            "Lokasi: $nearestLocation\n"
            "Jarak: ${minDistance.toStringAsFixed(1)} meter\n"
            "Radius yang diizinkan: ${allowedRadius.toStringAsFixed(0)} meter";
      } else {
        statusMessage =
            "❌ Anda terlalu jauh dari lokasi absensi\n"
            "Lokasi terdekat: $nearestLocation\n"
            "Jarak: ${minDistance.toStringAsFixed(1)} meter\n"
            "Radius yang diizinkan: ${allowedRadius.toStringAsFixed(0)} meter";
      }
      isLoading = false;
    });
  }

  // Buka halaman setup lokasi
  void _openLocationSetup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LocationSetupScreen(existingLocations: attendanceLocations),
      ),
    );

    if (result != null && mounted) {
      debugPrint("Received ${result.length} locations from setup");
      setState(() {
        attendanceLocations = result;
      });
      await _saveLocations();
      _checkDistance();

      // Tampilkan konfirmasi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${attendanceLocations.length} lokasi absensi tersimpan",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Fungsi absensi
  void _performAttendance() {
    if (!canAttend) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Anda harus berada dalam radius yang ditentukan"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Absensi Berhasil"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Waktu: ${DateTime.now().toString()}"),
              Text("Lokasi: $nearestLocation"),
              Text(
                "Koordinat: ${currentPosition!.latitude.toStringAsFixed(6)}, ${currentPosition!.longitude.toStringAsFixed(6)}",
              ),
              Text("Jarak: ${nearestDistance.toStringAsFixed(1)} meter"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Absensi GPS"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openLocationSetup,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Lokasi Absensi:",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: _openLocationSetup,
                          child: const Text("Setup"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (attendanceLocations.isEmpty)
                      const Text(
                        "Belum ada lokasi yang diatur\nTekan 'Setup' untuk menambah lokasi",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      )
                    else
                      ...attendanceLocations.map(
                        (location) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            "${location.name}: Radius ${location.radius.toStringAsFixed(0)}m",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Status Lokasi:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (currentPosition != null)
                      Text(
                        "Koordinat Anda: ${currentPosition!.latitude.toStringAsFixed(6)}, ${currentPosition!.longitude.toStringAsFixed(6)}",
                        style: const TextStyle(fontSize: 14),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: canAttend ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: isLoading ? null : _getCurrentLocation,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Refresh Lokasi",
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: canAttend && !isLoading ? _performAttendance : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canAttend ? Colors.green : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                "ABSENSI",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationSetupScreen extends StatefulWidget {
  final List<LocationData> existingLocations;

  const LocationSetupScreen({super.key, required this.existingLocations});

  @override
  LocationSetupScreenState createState() => LocationSetupScreenState();
}

class LocationSetupScreenState extends State<LocationSetupScreen> {
  final MapController mapController = MapController();
  List<LocationData> locations = [];
  List<Marker> markers = [];
  List<CircleMarker> circles = [];
  LatLng? selectedPosition;
  double selectedRadius = 10.0;
  TextEditingController nameController = TextEditingController();
  LatLng currentCenter = const LatLng(-6.2088, 106.8456); // Default Jakarta

  @override
  void initState() {
    super.initState();
    locations = List.from(widget.existingLocations);
    _getCurrentLocationForMap();
    _updateMapElements();
  }

  // Dapatkan lokasi saat ini untuk center peta
  Future<void> _getCurrentLocationForMap() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          currentCenter = LatLng(position.latitude, position.longitude);
        });
        // Pindah kamera ke lokasi saat ini
        mapController.move(currentCenter, 15.0);
      }
    } catch (e) {
      // Jika gagal, gunakan default Jakarta
      debugPrint("Error getting location: $e");
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    if (mounted) {
      setState(() {
        selectedPosition = position;
      });
      _showAddLocationDialog();
    }
  }

  void _updateMapElements() {
    markers.clear();
    circles.clear();

    // Tambahkan marker lokasi saat ini
    markers.add(
      Marker(
        point: currentCenter,
        child: const Icon(Icons.my_location, color: Colors.red, size: 30),
      ),
    );

    for (int i = 0; i < locations.length; i++) {
      final location = locations[i];

      // Tambahkan marker lokasi absensi
      markers.add(
        Marker(
          point: LatLng(location.latitude, location.longitude),
          child: GestureDetector(
            onTap: () => _showEditLocationDialog(i),
            child: Column(
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 40),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    location.name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Tambahkan lingkaran radius
      circles.add(
        CircleMarker(
          point: LatLng(location.latitude, location.longitude),
          radius: location.radius,
          color: Colors.blue.withValues(alpha: 0.2),
          borderColor: Colors.blue,
          borderStrokeWidth: 2,
        ),
      );
    }
  }

  void _showAddLocationDialog() {
    if (!mounted) return;

    nameController.clear();
    selectedRadius = 10.0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Tambah Lokasi Absensi"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Nama Lokasi",
                      hintText: "Contoh: Kantor Pusat",
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("Radius: ${selectedRadius.toStringAsFixed(0)} meter"),
                  Slider(
                    value: selectedRadius,
                    min: 5.0,
                    max: 100.0,
                    divisions: 19,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRadius = value;
                      });
                    },
                  ),
                  if (selectedPosition != null)
                    Text(
                      "Koordinat: ${selectedPosition!.latitude.toStringAsFixed(6)}, ${selectedPosition!.longitude.toStringAsFixed(6)}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty &&
                        selectedPosition != null) {
                      if (mounted) {
                        setState(() {
                          locations.add(
                            LocationData(
                              name: nameController.text,
                              latitude: selectedPosition!.latitude,
                              longitude: selectedPosition!.longitude,
                              radius: selectedRadius,
                            ),
                          );
                          _updateMapElements();
                        });
                      }
                      Navigator.pop(context);

                      // Tampilkan snackbar konfirmasi
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Lokasi '${nameController.text}' berhasil ditambahkan",
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text("Tambah"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditLocationDialog(int index) {
    if (!mounted) return;

    final location = locations[index];
    nameController.text = location.name;
    selectedRadius = location.radius;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Lokasi"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Nama Lokasi"),
                  ),
                  const SizedBox(height: 16),
                  Text("Radius: ${selectedRadius.toStringAsFixed(0)} meter"),
                  Slider(
                    value: selectedRadius,
                    min: 5.0,
                    max: 100.0,
                    divisions: 19,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRadius = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        locations.removeAt(index);
                        _updateMapElements();
                      });

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Lokasi berhasil dihapus"),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "Hapus",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      if (mounted) {
                        setState(() {
                          locations[index] = LocationData(
                            name: nameController.text,
                            latitude: location.latitude,
                            longitude: location.longitude,
                            radius: selectedRadius,
                          );
                          _updateMapElements();
                        });
                      }
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Lokasi '${nameController.text}' berhasil diupdate",
                          ),
                          backgroundColor: Colors.blue,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Setup Lokasi Absensi"),
        backgroundColor: Colors.blue,
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context, locations);
              }
            },
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: const Column(
              children: [
                Text(
                  "Tap pada peta untuk menambah lokasi absensi baru.",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Tap pada marker biru untuk mengedit lokasi yang sudah ada.",
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: currentCenter,
                initialZoom: 15.0,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.attendance_app',
                  maxNativeZoom: 19,
                  maxZoom: 19,
                  errorTileCallback: (tile, error, stackTrace) {
                    debugPrint('Tile loading error: $error');
                  },
                ),
                CircleLayer(circles: circles),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (mounted) {
            mapController.move(currentCenter, 15.0);
          }
        },
        tooltip: 'Kembali ke lokasi saya',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
