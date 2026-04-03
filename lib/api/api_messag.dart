import 'dart:convert';

import 'package:eshtreeli_captains_flutter/home.dart';
import 'package:eshtreeli_captains_flutter/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class firebaseApi {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// تهيئة Firebase + الحصول على FCM Token
  static Future init() async {
    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: true,
        criticalAlert: true,
        provisional: true,
        sound: true,
      );

      final token = await _firebaseMessaging.getToken();
      final prefs = await SharedPreferences.getInstance();

      if (token != null) {
        print('✅ FCM Token: $token');
        await prefs.setString('notitoken', token); // تم استبدال LocalStorage
      } else {
        print('⚠️ FCM Token is null. Device may restrict Google Services.');
        await prefs.setString('token', 'UNAVAILABLE');
      }
    } catch (e) {
      print('❌ Error in firebaseApi.init(): $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', 'ERROR');
    }
  }

  /// تهيئة Local Notifications
  static Future localNoti() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        onDidReceiveLocalNotification: (
          id,
          title,
          body,
          payload,
        ) =>
            null,
      );

      final LinuxInitializationSettings initializationSettingsLinux =
          LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        linux: initializationSettingsLinux,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: null,
      );
    } catch (e) {
      print('❌ Error in localNoti(): $e');
    }
  }

  /// عند الضغط على الإشعار
  static void onNotificationTap(NotificationResponse notificationResponse) {
    print("📲 تم الضغط على الإشعار");

    navigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => home()), // 👈 هون الهوم
      (route) => false,
    );

    Future.delayed(Duration(milliseconds: 500), () {
      notificationStream.add(null); // 👈 يحدث البيانات
    });
  }

  /// إظهار إشعار بسيط
  static Future showSimpleNoti({
    required String title,
    required String body,
    required dynamic payload,
  }) async {
    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'your channel Id',
        'your channel name',
        channelDescription: 'channel description',
        importance: Importance.max,
        priority: Priority.max,
        ticker: 'ticker',
      );

      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);

      await _flutterLocalNotificationsPlugin.show(
        0,
        title,
        body,
        notificationDetails,
        payload: payload is String ? payload : jsonEncode(payload),
      );
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  /// استرجاع الـ Token من SharedPreferences
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notitoken');
  }
}
