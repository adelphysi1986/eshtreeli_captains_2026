import 'package:eshtreeli_captains_flutter/home.dart';
import 'package:eshtreeli_captains_flutter/welcome.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class spinner extends StatefulWidget {
  const spinner({super.key});

  @override
  State<spinner> createState() => _spinnerState();
}

class _spinnerState extends State<spinner> {
  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');
    final id = prefs.getString('id');

    
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (token != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const home()),
        (route) => false,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => wel()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 174, 1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 50),
              height: 200,
              child: Image.asset('images/icon-3.png'),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
