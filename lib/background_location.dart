import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🔥 SERVICE STARTED");

  Timer.periodic(const Duration(seconds: 300), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null) return;

      final pos = await Geolocator.getCurrentPosition();

      await http.post(
        Uri.parse("http://192.168.1.6:5000/api/captain/location"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({"lat": pos.latitude, "lng": pos.longitude}),
      );

      print("📡 SENT ${pos.latitude} , ${pos.longitude}");
    } catch (e) {
      print("❌ BG ERROR $e");
    }
  });
}
