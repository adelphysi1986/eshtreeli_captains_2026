import 'dart:io';

import 'package:eshtreeli_captains_flutter/welcome.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class Profile extends StatefulWidget {
  @override
  State<Profile> createState() => _ProfileState();
  final String username;
  final String phone;
  final String subArea;
  final String categories;
  final double balance;
  final double total;
  final double rating;
  final String location;
  final int ban;
  final int orderscount;
  const Profile({
    super.key,
    required this.username,
    required this.phone,
    required this.subArea,
    required this.categories,
    required this.balance,
    required this.total,
    required this.rating,
    required this.location,
    required this.ban,
    required this.orderscount,
  });
}

class _ProfileState extends State<Profile> {
  String msg = '';

  String userphone = '';
  String username = '';
  String points = '';
  String dept = '';
  String captain_delivery = '';
  String captain_pay = '';

  bool isloading = false;

  /// ✅ جلب بيانات المستخدم

  /// ✅ Alert Box
  void openAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "!تنبيه",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          msg,
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text("تمام"),
            ),
          )
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Center(
          child: Text(
            "الملف الشخصي",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Divider(),
            _tile("اسم المستخدم", widget.username),
            _tile("رقم الجوال", widget.phone),
            //_tile("النقاط", widget.),
            _tile("مجموع التوصيل", widget.total.toString()),
            // _tile("الدفعات", widget.captain_pay),
            _tile("عدد الطلبات", widget.orderscount.toString()),
            _tile("الرصيد", widget.balance.toString()),
            Platform.isIOS
                ? //    const CircularProgressIndicator(),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      //   if (Platform.isAndroid) {
                      //  Navigator.push(
                      //  context,
                      //   MaterialPageRoute(
                      //   builder: (_) => DeleteAccountInfoPage(),
                      //   ),
                      //  );
                      //  }

                      //    else
                      if (Platform.isIOS) {
                        showDeleteConfirmDialog(context);
                      }
                    },
                    child: Text(
                        style: TextStyle(color: Colors.white), "حذف الحساب"),
                  )
                : SizedBox(),
          ],
        ),
      ),
    );
  }

  /// ✅ Widget Helper
  Widget _tile(String title, String value) {
    return Column(
      children: [
        ListTile(
          leading: Text(
            title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          trailing: Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        Divider(),
      ],
    );
  }
}

class DeleteAccountInfoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text("حذف الحساب")),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "لحذف حسابك من تطبيق اشتريلي، يرجى التواصل معنا عبر الصفحة التالية:",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 15),
              InkWell(
                onTap: () async {
                  final url = Uri.parse(
                      "https://eshtreeli-backend-2026-1.onrender.com/delete-account");
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    print("لا يمكن فتح الرابط: $url");
                  }
                },
                child: Text(
                  "https://eshtreeli-backend-2026-1.onrender.com/delete-account",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                "سيتم حذف الحساب خلال 24 ساعة بعد التأكيد.",
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LaunchMode {
  static var externalApplication;
}

void showDeleteConfirmDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد أنك تريد حذف حسابك؟"),
        actions: [
          TextButton(
            child: Text("إلغاء"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("تأكيد"),
            onPressed: () {
              Navigator.pop(context);
              DeleteAccountIOS(context);
            },
          ),
        ],
      );
    },
  );
}

Future<void> DeleteAccountIOS(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString("token"); // توكن الدخول
  if (token == null) return;

  try {
    final response = await http.put(
      Uri.parse(
          "https://eshtreeli-backend-2026-1.onrender.com/api/user/update-phone"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"phone": ""}), // حذف الرقم
    );

    final data = jsonDecode(response.body);

    // عرض الرسالة
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(data['message'] ?? "حدث خطأ")),
    );
    await Future.delayed(Duration(seconds: 1));

    // ✅ نفذ logout مباشرة
    await prefs.clear();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => wel()));
  } catch (e) {
    print(e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("حدث خطأ")),
    );
  }
}
