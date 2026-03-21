import 'package:eshtreeli_captains_flutter/signup.dart';
import 'package:eshtreeli_captains_flutter/spinner.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPhonePage extends StatefulWidget {
  const LoginPhonePage({super.key});

  @override
  State<LoginPhonePage> createState() => _LoginPhonePageState();
}

class _LoginPhonePageState extends State<LoginPhonePage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> loginPhone() async {
    String phone = phoneController.text.trim();
    String password = passwordController.text;

    if (phone.length != 10) {
      showAlert('يرجى إدخال رقم جوال صحيح (10 أرقام)');
      return;
    }
    if (password.isEmpty) {
      showAlert('يرجى إدخال كلمة المرور');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.6:5000/api/auth/login-phone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );

      setState(() {
        isLoading = false;
      });

      print('Status code: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['token'] != null) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString('id', data['user']['id'].toString());
          await prefs.setString('user_name', data['user']['name']);
          await prefs.setString('user_phone', data['user']['phone']);
          print("TOKEN SAVED: ${prefs.getString('token')}");
          print("ID SAVED: ${prefs.getString('id')}");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => spinner()),
          );
        } else if (data['data_ban'] == 'العضوية محظورة') {
          showAlert('تم حظر حسابك، راجع الإدارة');
        } else {
          showAlert('رقم الجوال أو كلمة المرور خاطئة، حاول مرة أخرى');
        }
      } else if (response.statusCode == 401) {
        showAlert('رقم الجوال أو كلمة المرور خاطئة');
      } else if (response.statusCode == 403) {
        showAlert('تم حظر حسابك، راجع الإدارة');
      } else {
        showAlert('حدث خطأ في السيرفر، حاول لاحقًا');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error: $e');
      showAlert('حدث خطأ يرجى المحاولة لاحقًا');
    }
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '!خطأ',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('تمام'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Color.fromARGB(255, 255, 253, 250),
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                Text(
                  "تسجيل دخول بالجوال",
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  decoration: InputDecoration(
                    hintText: 'رقم الجوال',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'كلمة المرور',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                isLoading
                    ? CircularProgressIndicator(color: Colors.green)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          fixedSize: Size(double.infinity, 50),
                        ),
                        onPressed: loginPhone,
                        child: Text(
                          "تسجيل الدخول",
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("لا تملك حساب؟"),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => signup()),
                        );
                      },
                      child: Text(
                        "إنشاء حساب",
                        style: TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
