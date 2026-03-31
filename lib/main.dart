import 'dart:convert';

import 'package:eshtreeli_captains_flutter/api/api_messag.dart';
import 'package:eshtreeli_captains_flutter/api/message.dart';
import 'package:eshtreeli_captains_flutter/spinner.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// 👇 مهم
import 'package:flutter_background_service/flutter_background_service.dart';
import 'background_location.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firbaseBackGroundMessaging(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (message.notification != null) {
    print('background moti');
  }
}

// 👇🔥 تهيئة الخدمة (السبب الحقيقي لمشكلتك)
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart, // 👈 يربط مع background_location.dart
      isForegroundMode: true,
      autoStart: false,
      foregroundServiceNotificationId: 888,
      initialNotificationTitle: "Eshtreeli",
      initialNotificationContent: "جاري مشاركة موقعك",
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 أهم سطر كان ناقصك
  await initializeService();

  try {
    await Firebase.initializeApp();
    print("Firebase initialized successfully");
  } catch (e) {
    print("Firebase initialization failed: $e");
  }

  await firebaseApi.init();
  await firebaseApi.localNoti();

  FirebaseMessaging.onBackgroundMessage(_firbaseBackGroundMessaging);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    String payloadData = jsonEncode(message.data);
    print('got a message in foreground');

    if (message.notification != null) {
      firebaseApi.showSimpleNoti(
        title: message.notification!.title!,
        body: message.notification!.body!,
        payload: payloadData,
      );
    }
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('ar'),
      navigatorKey: navigatorKey,
      routes: {
        "/message": (context) => message(),
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromARGB(255, 255, 255, 255),
        ),
        fontFamily: 'arabic',
      ),
      debugShowCheckedModeBanner: false,
      title: 'Your app name',
      home: spinner(),
    );
  }
}
