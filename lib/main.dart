import 'dart:async' show unawaited;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:absensikaryawan/Screen%20User/splash_screen.dart';
import 'package:absensikaryawan/Services/fcm_service.dart';
import 'package:absensikaryawan/Services/token_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(const MyApp());

  // Persiapan channel, permission, dan listener notifikasi tidak perlu
  // menahan splash screen. Firebase inti tetap disiapkan sebelum runApp.
  if (!kIsWeb) {
    _initializeNotificationsInBackground();
  }
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
      unawaited(TokenService.getToken());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SENADA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
    );
  }
}

