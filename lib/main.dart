import 'dart:convert';
import 'package:eshtreeli_captains_flutter/api/api_messag.dart';
import 'package:eshtreeli_captains_flutter/api/message.dart';
import 'package:eshtreeli_captains_flutter/firebase_options.dart';
import 'package:eshtreeli_captains_flutter/spinner.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

final navigatorKey = GlobalKey<NavigatorState>();
@pragma('vm:entry-point')
//Future<void> _firebaseBackgroundMessaging(RemoteMessage message) async {
// await Firebase.initializeApp();
//}

Future _firbaseBackGroundMessaging(RemoteMessage message) async {
  if (message.notification != null) {
    print('background moti');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print("Firebase initialized successfully");
  } catch (e) {
    print("Firebase initialization failed: $e");
  }

  await FirebaseApi.init();
  await FirebaseApi.localNoti();

  FirebaseMessaging.onBackgroundMessage(_firbaseBackGroundMessaging);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      final payload = jsonEncode(message.data);

      print('Foreground notification: ${message.notification!.title}');

      FirebaseApi.showSimpleNoti(
        title: message.notification!.title!,
        body: message.notification!.body!,
        payload: payload,
      );
    }
  });

  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      final payload = jsonEncode(message.data);

      navigatorKey.currentState?.pushNamed(
        "/message",
        arguments: payload,
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final payload = jsonEncode(message.data);

    navigatorKey.currentState?.pushNamed(
      "/message",
      arguments: payload,
    );
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      routes: {
        "/message": (context) => message(),
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 255, 255, 255),
        ),
        fontFamily: 'arabic',
      ),
      debugShowCheckedModeBanner: false,
      title: 'Eshtreeli Captains',
      home: spinner(),
    );
  }
}
