import 'dart:async' show unawaited;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:absensikaryawan/Screen%20User/splash_screen.dart';
import 'package:absensikaryawan/Screen%20HRD/Home/attendance_monitor_screen.dart';
import 'package:absensikaryawan/Services/fcm_service.dart';
import 'package:absensikaryawan/Services/token_service.dart';
import 'package:absensikaryawan/firebase_web_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(options: FirebaseWebOptions.current);
  } else {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(const MyApp());

  // Persiapan channel, permission, dan listener notifikasi tidak perlu
  // menahan splash screen. Firebase inti tetap disiapkan sebelum runApp.
  _initializeNotificationsInBackground();
}

Future<void> _initializeNotificationsInBackground() async {
  try {
    await FcmService.init();
  } catch (_) {
    // Kegagalan notifikasi tidak boleh menghalangi aplikasi dibuka.
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Berlaku untuk Android, iOS, dan web: ketika aplikasi/tab kembali
      // aktif, perbarui access token bila perlu. Kegagalan jaringan sengaja
      // diabaikan; tidak boleh berubah menjadi aksi logout lokal.
      unawaited(_refreshSessionAndNotifications());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kedua alamat Web (/#/monitor dan /monitor) membuka satu rute saja.
    // Generator awal bawaan Flutter dapat membuat '/' di bawah '/monitor';
    // SplashScreen di rute '/' lalu bernavigasi otomatis dan menimpa monitor.
    final monitorRequested = kIsWeb &&
        (Uri.base.fragment == '/monitor' ||
            Uri.base.path.replaceFirst(RegExp(r'/+$'), '') == '/monitor');
    return MaterialApp(
      title: 'SENADA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      onGenerateInitialRoutes: (initialRouteName) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: monitorRequested ? '/monitor' : '/'),
          builder: (_) => monitorRequested
              ? const AttendanceMonitorScreen()
              : const SplashScreen(),
        ),
      ],
      routes: {
        '/': (_) => const SplashScreen(),
        '/monitor': (_) => const AttendanceMonitorScreen(),
      },
    );
  }
}

Future<void> _refreshSessionAndNotifications() async {
  final token = await TokenService.getToken();
  if (token != null && token.isNotEmpty) {
    await FcmService.uploadToken();
  }
}
