import 'package:eshtreeli_captains_flutter/otp.dart';

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Reagion {
  final String id;
  final String nameRe;

  const Reagion({required this.id, required this.nameRe});

  factory Reagion.fromJson(Map<String, dynamic> json) {
    return Reagion(
      id: json['_id']?.toString() ?? '',
      nameRe: json['name']?.toString() ?? '',
    );
  }
}

class City {
  final String id;
  final String name;

  const City({required this.id, required this.name});

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['_id'],
      name: json['name'],
    );
  }
}

class Policey {
  final String policie_title;
  final String policie_description;

  const Policey(
      {required this.policie_title, required this.policie_description});

  factory Policey.fromJson(Map<String, dynamic> json) {
    return Policey(
      policie_title: json['policie_title'],
      policie_description: json['policie_description'],
    );
  }
}

// ================== API Functions ==================
Future<List<City>> fetchMainPlace() async {
  final response =
      await http.get(Uri.parse('http://192.168.1.6:5000/api/main-areas'));
  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => City(id: e['_id'], name: e['name'])).toList();
  } else {
    throw Exception('Failed to load City');
  }
}

Future<List<Reagion>> fetchSubAreas(String mainAreaId) async {
  final response = await http.post(
    Uri.parse('http://192.168.1.6:5000/api/sub-areas-by-main'),
    headers: <String, String>{'Content-Type': 'application/json'},
    body: jsonEncode({'mainAreaId': mainAreaId}),
  );
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['data'] == null) return [];
    return List<Reagion>.from(data['data'].map((x) => Reagion.fromJson(x)));
  } else {
    throw Exception('Failed to load SubAreas');
  }
}

// ================== تسجيل الحساب ==================
// ======== دالة التسجيل ========
Future<void> fitchSignup(
  String name,
  String phone,
  String password,
  String mainArea,
  String subArea,
) async {
  final response = await http.post(
    Uri.parse('http://192.168.1.6:5000/api/auth/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'name': name,
      'email': '$name@gmail.com', // ايميل ثابت
      'password': password,
      'phone': phone,
      'role': 'captain',
      'location': mainArea,
      'subArea': subArea,
    }),
  );

  final body = jsonDecode(response.body);

  if (response.statusCode != 201) {
    // إذا السيرفر أعطى رسالة خطأ، ارجعها
    throw Exception(body['message'] ?? 'فشل إنشاء الحساب');
  }
}

// ================== Signup Page ==================
class signup extends StatefulWidget {
  const signup({super.key});

  @override
  State<signup> createState() => _signupState();
}

class _signupState extends State<signup> {
  String username = '';
  String phone = '';
  String password = '';
  String name = ''; // المدينة الرئيسية
  String nameRe = ''; // المنطقة التفصيلية
  bool? isChecked = false;
  bool isloading = false;

  late TextEditingController controller;
  late TextEditingController controller2;
  late TextEditingController controller4;

  late Future<List<City>> city;
  Future<List<Reagion>>? region;
  Future<List<Policey>>? policy;

  @override
  void initState() {
    super.initState();
    city = fetchMainPlace();
    controller = TextEditingController();
    controller2 = TextEditingController();
    controller4 = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    controller2.dispose();
    controller4.dispose();
    super.dispose();
  }

  // ======== دالة إنشاء الحساب ========
  void create() async {
    // التحقق من الحقول أولاً
    if (username.isEmpty ||
        phone.length < 10 ||
        password.isEmpty ||
        name.isEmpty ||
        nameRe.isEmpty ||
        isChecked != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء تعبئة جميع الحقول بشكل صحيح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isloading = true;
    });

    try {
      // إرسال البيانات للسيرفر
      await fitchSignup(username, phone, password, name, nameRe);
      setState(() {
        isloading = false;
      });

      // إذا تم بنجاح، الانتقال لصفحة OTP
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => otp(phone: phone, forget: ''),
        ),
      );
    } catch (e) {
      setState(() {
        isloading = false;
      });

      // عرض رسالة الخطأ للمستخدم مباشرة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // =============== Modals ===============
  void openModal() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, controllerScroll) {
          return Column(
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: 20),
                child: Text("اختر منطقتك الرئيسية",
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: FutureBuilder<List<City>>(
                  future: city,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child:
                              CircularProgressIndicator(color: Colors.orange));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('لا توجد بيانات'));
                    } else {
                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          City data = snapshot.data![index];
                          return ListTile(
                            title: Text(data.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () {
                              setState(() {
                                name = data.name;
                                region = fetchSubAreas(data.id);
                                nameRe = '';
                              });

                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void openModal2() {
    if (region == null) return;
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, controllerScroll) {
          return Column(
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: 20),
                child: Text("اختر منطقتك التفصيلية",
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: FutureBuilder<List<Reagion>>(
                  future: region,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child:
                              CircularProgressIndicator(color: Colors.orange));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('لا توجد بيانات'));
                    } else {
                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          Reagion data = snapshot.data![index];
                          return ListTile(
                            title: Text(data.nameRe,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () {
                              setState(() {
                                nameRe = data.nameRe;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ================== Build ==================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Color.fromARGB(255, 255, 253, 250),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("إنشاء حساب جديد",
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange)),
                SizedBox(height: 10),
                SizedBox(
                  width: 265,
                  child: TextField(
                    controller: controller,
                    onChanged: (value) => setState(() => username = value),
                    decoration: InputDecoration(
                        hintText: 'الإسم باكامل',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15))),
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: 265,
                  child: TextField(
                    controller: controller2,
                    maxLength: 10,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(() => phone = value),
                    decoration: InputDecoration(
                        hintText: 'رقم الجوال',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15))),
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: 265,
                  child: TextField(
                    controller: controller4,
                    obscureText: true,
                    onChanged: (value) => setState(() => password = value),
                    decoration: InputDecoration(
                        hintText: 'كلمة المرور',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15))),
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: 265,
                  child: ElevatedButton(
                    onPressed: openModal,
                    child: Text(name.isEmpty ? "منطقتك الرئيسية" : name),
                  ),
                ),
                SizedBox(height: 10),
                if (name.isNotEmpty)
                  SizedBox(
                    width: 265,
                    child: ElevatedButton(
                      onPressed: openModal2,
                      child: Text(
                          nameRe.isEmpty ? "اختر منطقتك التفصيلية" : nameRe),
                    ),
                  ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: isChecked,
                      onChanged: (value) => setState(() => isChecked = value),
                    ),
                    Text("اقر باني سالتزم بتعليمات مشغلين التطبيق",
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: 250,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: create,
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: Text("اضغط للمتابعة",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================== صفحة OTP ==================
