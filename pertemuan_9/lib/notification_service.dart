import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'notification_detail_screen.dart';

/// Top-level handler untuk menangani pesan FCM saat aplikasi di background / terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background message diterima: ${message.messageId}');
}

/// Service untuk inisialisasi FCM, local notification, dan navigasi notifikasi.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Channel untuk notifikasi penting dari Firebase Cloud Messaging',
    importance: Importance.max,
  );

  /// Menggabungkan notification (title, body) menjadi satu .
  Map<String, dynamic> _messageToMap(RemoteMessage message) {
    return {
      'title': message.notification?.title ?? message.data['title'] ?? '',
      'body': message.notification?.body ?? message.data['body'] ?? '',
      ...message.data,
    };
  }

  /// Inisialisasi izin notifikasi, channel Android, dan listener FCM.
  Future<void> initialize() async {
    
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(_channel);

    //  Inisialisasi Flutter Local Notifications untuk tampilan saat foreground
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          final decoded =
              jsonDecode(response.payload!) as Map<String, dynamic>;
          _openDetailScreen(decoded);
        }
      },
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // saat aplikasi terbuka (Foreground)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // saat notifikasi diklik dari kondisi Background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Cek jika aplikasi dibuka dari notifikasi saat kondisi Terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleMessageOpenedApp(initialMessage);
      });
    }
  }

  /// Menampilkan banner notifikasi lokal saat aplikasi di foreground.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = _messageToMap(message);
    final title = data['title']?.toString() ?? 'Notifikasi';
    final body = data['body']?.toString() ?? '';

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  /// Menangani klik notifikasi dari background / terminated.
  void _handleMessageOpenedApp(RemoteMessage message) {
    _openDetailScreen(_messageToMap(message));
  }

  void _openDetailScreen(Map<String, dynamic> data) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(data: data),
      ),
    );
  }

  /// Mengambil FCM Token perangkat saat ini.
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}