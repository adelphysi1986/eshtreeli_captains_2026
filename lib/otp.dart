import 'package:eshtreeli_captains_flutter/spinner.dart';

import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Otp {
  var token;
  Otp({required this.token});

  factory Otp.fromJson(json) {
    //تحويل المفكو
    //ك من الجيسون بلغة دارت للمعلومات
    return Otp(
      token: json['token'],
    );
  }
}

class otp extends StatefulWidget {
  final phone;
  final forget;
  const otp({required this.phone, required this.forget});

  @override
  State<otp> createState() => _otpState();
}

class _otpState extends State<otp> {
  bool isloading = false;

  String false_data = '';

  fitchsendcode() async {
    final response = await http.post(
      Uri.parse(
          'https://eshtreeli-backend-2026-1.onrender.com/api/send_code_v'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'customers_mobile': widget.phone,
        'customer_code_active': 1234,
      }),
    );

    if (response.statusCode == 200) {
      // فك الجيسون وتحويله لدارت
    } else {
      throw Exception('error');
    }
  }

  Future<Otp> fitchOtp(verificationCode) async {
    setState(() {
      isloading = true;
    });
    final response = await http.post(
      Uri.parse(
          'https://eshtreeli-backend-2026-1.onrender.com/api/check_code_ative_user'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'customers_mobile': widget.phone,
        'customer_code_active': verificationCode,
      }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      if (body['data_false'] != 'لم يتم التفعيل') {
        setState(() {
          isloading = false;
        });

        // ✅ استخدام SharedPreferences بدل localStorage
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', body['token']);
        await prefs.setString('id', body['data']['id'].toString());

        setState(() {
          false_data = '';
        });

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => spinner()),
          (Route<dynamic> route) => false,
        );
      } else {
        setState(() {
          isloading = false;
        });
        setState(() {
          false_data =
              'لم يتم التفعيل! الرمز الذي ادخلته خاطئ اعد ادخاله من جديد( و لوحة المفاتيح انجليزي)';
        });
      }

      return Otp.fromJson(body);
    } else {
      throw Exception('error');
    }
  }

  @override
  void initState() {
    super.initState();
    fitchsendcode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.all(40),
              child: Text(
                widget.forget == ''
                    ? 'الرمز الخاص بك هو 1234 قم بادخاله في الخانات ادناه'
                    : ' انتظر لحظات ستصلك رسالة  على الرقم المدخل تحوي رمز التفعيل ،و(الكيبورد انجليزي) ادخل الرمز المرسل في الفراغات ادناه',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(20),
              child: OtpTextField(
                numberOfFields: 4,
                borderColor: Colors.orange,
                focusedBorderColor: Colors.green,
                showFieldAsBox: false,
                borderWidth: 4.0,
                onCodeChanged: (String code) async {},
                onSubmit: (String verificationCode) {
                  fitchOtp(verificationCode);
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.all(40),
              child: !isloading
                  ? Text(
                      false_data,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    )
                  : const CircularProgressIndicator(),
            ),
          ],
        ));
  }
}
