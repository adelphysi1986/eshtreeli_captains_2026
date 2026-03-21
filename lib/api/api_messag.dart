import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class FirebaseApi {
  /// Firebase Messaging instance
  static FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;

  /// Local Notifications instance
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    String? token;

    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        await Future.delayed(const Duration(seconds: 3));

        token = await _firebaseMessaging.getToken();

        if (token != null) break;
      } catch (e) {
        print("⚠️ Attempt ${attempt + 1} failed: $e");
      }
    }

    if (token == null) {
      print("❌ Failed to get FCM Token after retries.");
    } else {
      print("✅ FCM Token: $token");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("notitoken", token);
    }
  }

  static Future<void> localNoti() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onNotificationTap,
    );
  }

  /// Notification tap handler
  static void onNotificationTap(NotificationResponse response) {
    navigatorKey.currentState?.pushNamed(
      "/message",
      arguments: response.payload,
    );
  }

  /// Show a simple notification
  static Future<void> showSimpleNoti({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      "main_channel",
      "Main Notifications",
      channelDescription: "App notifications channel",
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
