import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:absensikaryawan/Services/config.dart';

// Top-level function — hanya dipakai di Android/iOS
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'senada_high_importance',
  'SENADA Notifications',
  description: 'Notifikasi pengajuan dan persetujuan SENADA',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotif =
    FlutterLocalNotificationsPlugin();

// Data pending-navigation dari notifikasi yang di-tap — dibawa sampai home
// screen siap menavigasi ke layar yang dimaksud (mis. reimbursement tertentu).
class PendingNav {
  final String type;
  final String? referenceId;
  const PendingNav(this.type, this.referenceId);
}

class FcmService {
  static PendingNav? _pendingNavigation;

  static Future<void> init() async {
    // Semua ini hanya untuk mobile — web tidak support
    if (kIsWeb) return;

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotifTap,
    );

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTap);

    final initial = await messaging.getInitialMessage();
    if (initial != null) _onMessageTap(initial);
  }

  static Future<void> uploadToken() async {
    if (kIsWeb) return; // notif push tidak tersedia di web
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('UserID');
      if (userId == null || userId.isEmpty) return;

      final role = (prefs.getString('Role') ?? '').toLowerCase();
      if (role == 'hrd') {
        await FirebaseMessaging.instance.subscribeToTopic('hrd_notifications');
      } else if (role == 'admin') {
        await FirebaseMessaging.instance.subscribeToTopic('admin_notifications');
      }

      // Notifikasi personal (mis. Finance yang di-assign ke reimbursement
      // tertentu) lewat topic per-user ini — tidak perlu lagi cek role
      // Head Finance secara terpisah.
      await FirebaseMessaging.instance.subscribeToTopic('user_$userId');
      await _postToken(userId, token);

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final p = await SharedPreferences.getInstance();
        final uid = p.getString('UserID');
        if (uid != null && uid.isNotEmpty) await _postToken(uid, newToken);
      });
    } catch (_) {}
  }

  static Future<void> _postToken(String userId, String token) async {
    try {
      final tokenRes = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 10));
      if (tokenRes.statusCode != 200) return;
      final accessToken = json.decode(tokenRes.body)['access_token'] as String?;
      if (accessToken == null) return;

      await http.post(
        Uri.parse('$baseURL/api/fcm/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'userId': userId,
          'fcmToken': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );
    } catch (_) {}
  }

  static Future<void> deleteToken() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('UserID');
      final role = (prefs.getString('Role') ?? '').toLowerCase();

      if (role == 'hrd') {
        await FirebaseMessaging.instance.unsubscribeFromTopic('hrd_notifications');
      } else if (role == 'admin') {
        await FirebaseMessaging.instance.unsubscribeFromTopic('admin_notifications');
      }
      if (userId != null && userId.isNotEmpty) {
        await FirebaseMessaging.instance.unsubscribeFromTopic('user_$userId');
      }

      if (userId != null && userId.isNotEmpty) {
        final tokenRes = await http.post(
          Uri.parse('$baseURL/api/auth/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'grant_type': 'password', 'password': 'ASN_DBS'},
        );
        if (tokenRes.statusCode == 200) {
          final accessToken = json.decode(tokenRes.body)['access_token'] as String?;
          if (accessToken != null) {
            await http.delete(
              Uri.parse('$baseURL/api/fcm/token/$userId'),
              headers: {'Authorization': 'Bearer $accessToken'},
            );
          }
        }
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  static PendingNav? consumePendingNavigation() {
    final nav = _pendingNavigation;
    _pendingNavigation = null;
    return nav;
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    _localNotif.show(
      message.messageId.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _onMessageTap(RemoteMessage message) {
    final type = message.data['type'];
    if (type == null) return;
    _pendingNavigation = PendingNav(type, message.data['referenceId']);
  }

  static void _onLocalNotifTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == null) return;
      _pendingNavigation = PendingNav(type, data['referenceId'] as String?);
    } catch (_) {}
  }
}
