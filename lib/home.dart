import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eshtreeli_captains_flutter/IncompleteOrdersPage.dart';
import 'package:eshtreeli_captains_flutter/about.dart';
import 'package:eshtreeli_captains_flutter/finishedOrders.dart';
import 'package:eshtreeli_captains_flutter/main.dart';
import 'package:eshtreeli_captains_flutter/notifications.dart';
import 'package:eshtreeli_captains_flutter/profile.dart';
import 'package:eshtreeli_captains_flutter/signup.dart';
import 'package:eshtreeli_captains_flutter/welcome.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'background_location.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class home extends StatefulWidget {
  const home({super.key});

  @override
  State<home> createState() => _homeState();
}

class _homeState extends State<home> {
  StreamSubscription? notificationSub;
  String? expandedOrderId;
  late IO.Socket socket;
  StreamSubscription<Position>? positionSub;
  StreamSubscription<ServiceStatus>? gpsServiceSub;
  Timer? gpsTimer;
  bool gpsDialogVisible = false;

  String msg = ' ';
  String username = '';
  String userphone = '';
  int userplaceId = 1;
  bool isloadingAgree = false;
  List data = [];
  List dataAprroved = [];
  String phone = '';
  String subArea = '';
  String categories = '';
  double rating = 0.0;
  num starts_counts = 0;
  double balance = 0.0;
  double total = 0.0;
  int status = 0;
  String location = "";
  int ban = 0;
  int orderscount = 0;
  bool isLoading = true; // لتحديد حالة تحميل البيانات

  String idUser = '';
  void initSocket() {
    socket = IO.io(
      'https://eshtreeli-backend-2026-1.onrender.com',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print("🟢 SOCKET CONNECTED");
      startForegroundLocation();
    });

    socket.onDisconnect((_) {
      print("🔴 SOCKET DISCONNECTED");
    });
  }

  void startForegroundLocation() {
    positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((pos) {
      socket.emit("captainLocation", {
        "lat": pos.latitude,
        "lng": pos.longitude,
        "captainId": idUser,
      });

      print("📡 SOCKET SENT ${pos.latitude}, ${pos.longitude}");
    });
  }

  Future<void> refresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await fetchUser();
    await fetchNewOrdersCaptain();
    await saveToken();
  }

  void startGpsWatcher() {
    gpsTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      bool enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled && !gpsDialogVisible && mounted) {
        gpsDialogVisible = true;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("GPS مغلق"),
            content: const Text("يجب تشغيل الموقع للاستمرار"),
            actions: [
              TextButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                },
                child: const Text("تشغيل GPS"),
              ),
              TextButton(
                onPressed: () {
                  exit(0);
                },
                child: const Text("خروج", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      }

      if (enabled && gpsDialogVisible && mounted) {
        gpsDialogVisible = false;
        Navigator.of(context, rootNavigator: true).pop();
        startBackground();
      }
    });
  }

  openAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'تمام',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
        title: const Text(
          "!تنبيه",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        contentPadding: const EdgeInsets.all(5),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> saveToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idUser = prefs.getString('id');

      if (idUser == null) return;
      final token = prefs.getString('notitoken');

      if (token == null) {
        print("FCM token still null");
        return;
      }

      await http.post(
        Uri.parse(
            'https://eshtreeli-backend-2026-1.onrender.com/api/save_token_expo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': idUser, 'token': token}),
      );

      print("TOKEN SENT TO SERVER $token");
    } catch (e) {
      print("Error saveToken: $e");
    }
  }

  Future<void> _launchURLwatts(String num, String prefex) async {
    final Uri url = Uri.parse("whatsapp://send?text=مرحبا&phone=$prefex$num");

    if (!await launchUrl(url)) {
      setState(() {
        msg = 'يجب ان يكون على جهازك تطبيق واتس اب';
      });
      openAlert();
      throw Exception('Could not launch');
    }
  }

  void _launchPhoneDialer(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  Future<void> fetchUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      idUser = prefs.getString('id') ?? '';

      if (token == null) {
        logout();
        return;
      }
      setState(() {
        isLoading = true;
      });
      final response = await http.get(
        Uri.parse('https://eshtreeli-backend-2026-1.onrender.com/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final user = jsonDecode(response.body)['user'];
        print(user);
        setState(() {
          username = user['name'] ?? '';
          phone = user['phone'] ?? '';
          subArea = user['subArea'] ?? '';

          categories = user['categories']?.toString() ?? '';
          balance = (user['balance'] ?? 0).toDouble();
          total = (user['total'] ?? 0).toDouble();
          rating = (user['rating'] ?? 0).toDouble();
          orderscount = user['orderscount'] ?? 0;
          location = user['location'] ?? '';
          ban = user['ban'] ?? 0;
        });
        fetchNewOrdersCaptain();
        initSocket();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      print("Error fetching user: $e");
    }
  }

  logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => wel()),
    );
  }

  Future<void> fetchNewOrdersCaptain() async {
    setState(() {
      isLoading = true; // قبل جلب البيانات، ضع المؤشر
    });

    try {
      /*  */
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null) {
        logout();
        return;
      }
      final response = await http.get(
        Uri.parse(
            "https://eshtreeli-backend-2026-1.onrender.com/api/orders/new-orders"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        setState(() {
          data = result["orders"];
          isLoading = false; // بعد جلب البيانات، إخفاء المؤشر
        });

        print(data);
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تواصل معنا لبدء بالعمل 🚀"),
            duration: Duration(seconds: 3),
          ),
        );
        print("❌ خطأ في جلب الطلبات: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      print("Error fetchNewOrdersCaptain: $e");
    }
  }

  Future<void> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
  }

  Future<void> startBackground() async {
    final service = FlutterBackgroundService();

    bool isRunning = await service.isRunning();

    if (isRunning) {
      print("⚠️ Service already running");
      return;
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
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

    service.startService();

    print("🚀 START SERVICE CALLED");
  }

  @override
  void initState() {
    super.initState();
    notificationSub = notificationStream.stream.listen((_) async {
      print("🔥 جا إشعار - رح نحدث البيانات");

      await Future.delayed(Duration(seconds: 2)); // 👈 هون التعديل

      await fetchNewOrdersCaptain();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initAfterUI();
    });
  }

  Future<void> initAfterUI() async {
    await requestLocationPermission();

    startGpsWatcher();
    fetchUser();
    saveToken();
    await Permission.notification.request();
    //  startBackground();
  }

  @override
  void dispose() {
    gpsServiceSub?.cancel();
    positionSub?.cancel();
    socket.dispose();
    gpsTimer?.cancel();
    notificationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        icon: Icon(Icons.local_taxi, color: Colors.white),
        label: Text(
          "طلبات قيد الإنجاز",
          style: TextStyle(color: Colors.white),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CaptainOrdersPage(),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      endDrawer: Drawer(
        child: Container(
          color: const Color.fromARGB(255, 248, 248, 248),
          child: idUser == ''
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 255, 255, 255),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => signup(),
                            ),
                          );
                        },
                        child: const Text(
                          "انشاء حساب",
                          style: TextStyle(
                            color: Color.fromARGB(255, 106, 106, 106),
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView(
                  children: [
                    SizedBox(
                      height: 180,
                      child: DrawerHeader(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.black,
                              ),
                              height: 50,
                              width: 50,
                              child: Image.asset(
                                'images/icon-1.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                            Text(
                              '!اهلا ' + username,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            RatingBarIndicator(
                              rating: rating,
                              itemBuilder: (context, index) => const Icon(
                                Icons.star,
                                color: Color.fromARGB(255, 248, 199, 51),
                              ),
                              itemCount: 5,
                              itemSize: 30,
                              direction: Axis.horizontal,
                            ),
                          ],
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text(
                        'الرئيسية',
                        textAlign: TextAlign.end,
                      ),
                      leading: const Icon(Icons.home),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Profile(
                              username: username,
                              phone: phone,
                              subArea: subArea,
                              categories: categories,
                              balance: balance,
                              total: total,
                              rating: rating,
                              location: location,
                              ban: ban,
                              orderscount: orderscount,
                            ),
                          ),
                        );
                      },
                      child: const ListTile(
                        title: Text(
                          'حسابي',
                          textAlign: TextAlign.end,
                        ),
                        leading: Icon(Icons.person),
                      ),
                    ),

                    ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CaptainOrdersPage()),
                        );
                      },
                      title: const Text(
                        'طلبات قيد الانجاز',
                        textAlign: TextAlign.end,
                      ),
                      leading: const Icon(Icons.folder),
                    ),
                    ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => finishedOrders()),
                        );
                      },
                      title: const Text(
                        'الطلبات المنجزة',
                        textAlign: TextAlign.end,
                      ),
                      leading: const Icon(Icons.folder),
                    ),
                    ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => NotificationsScreen()),
                        );
                      },
                      title: const Text(
                        'الإشعارات',
                        textAlign: TextAlign.end,
                      ),
                      leading: const Icon(Icons.notifications),
                    ),
                    // ListTile(
                    //  title: const Text(
                    //   'عن التطبيق',
                    //   textAlign: TextAlign.end,
                    //  ),
                    //   leading: const Icon(Icons.info),
                    // onTap: () {
                    //    Navigator.pop(context);
                    //    Navigator.push(
                    //     context,
                    //     MaterialPageRoute(builder: (context) => about()),
                    //   );
                    //  },
                    //  ),
                    ListTile(
                      title: const Text(
                        'تسجيل خروج',
                        textAlign: TextAlign.end,
                      ),
                      leading: const Icon(Icons.exit_to_app),
                      onTap: () {
                        logout();
                      },
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(), // مؤشر التحميل
                )
              : data.isEmpty
                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(), // مهم للسحب
                      children: const [
                        SizedBox(
                          height: 200, // ارتفاع كافي لعرض الرسالة
                          child: Center(
                            child: Text(
                              "لا يوجد طلبات جديدة حاليا",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    )
                  : data.isEmpty
                      ? const Center(
                          child: Text(
                            "لا يوجد طلبات جديدة حاليا", // رسالة عند عدم وجود بيانات
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : ListView.builder(
                          itemCount: data.isEmpty ? 1 : data.length,
                          itemBuilder: (context, index) {
                            if (data.isEmpty) {
                              return SizedBox(
                                height: MediaQuery.of(context).size.height -
                                    kToolbarHeight,
                                child: const Center(
                                  child: Text(
                                    "لا يوجد طلبات جديدة حاليا",
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              );
                            }

                            final order = data[index];

                            // رقم الطلب مختصر من _id
                            String orderNumber = (order['_id'] ?? '-----')
                                .toString()
                                .substring(0, 6);

                            // حماية من null أو empty
                            String startLoc =
                                (order['startLocation'] ?? '').isNotEmpty
                                    ? order['startLocation']
                                    : "غير محدد";

                            String endLoc =
                                (order['endLocation'] ?? '').isNotEmpty
                                    ? order['endLocation']
                                    : "غير محدد";

                            num deliveryPrice =
                                (order['deliveryPrice'] ?? 0).round();

                            Widget deliveryPriceWidget = deliveryPrice == 0
                                ? const Text(
                                    "انت ستحدد سعر التوصيل",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  )
                                : Text(
                                    "سعر التوصيل: $deliveryPrice",
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  );

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(
                                  color: expandedOrderId == order['_id']
                                      ? Colors.green
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              elevation: 3,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    // إذا ضغط عليه مرة ثانية يسكر
                                    if (expandedOrderId == order['_id']) {
                                      expandedOrderId = null;
                                    } else {
                                      expandedOrderId = order['_id'];
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      /// ✅ العنوان الرئيسي
                                      Text(
                                        "طلب رقم: ${order['_id'].toString().substring(0, 6)}",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      /// ✅ الموقع
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 18, color: Colors.blue),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              "من: ${order['startLocation'] ?? 'غير محدد'}",
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 4),

                                      Row(
                                        children: [
                                          const Icon(Icons.flag,
                                              size: 18, color: Colors.orange),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              "إلى: ${order['endLocation'] ?? 'غير محدد'}",
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      /// ✅ السعر
                                      deliveryPrice == 0
                                          ? const Text(
                                              "انت ستحدد سعر التوصيل",
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold),
                                            )
                                          : Text(
                                              "سعر التوصيل: $deliveryPrice",
                                              style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold),
                                            ),

                                      /// ==========================================
                                      /// ✅ التفاصيل تظهر فقط عند التوسيع
                                      /// ==========================================

                                      if (expandedOrderId == order['_id']) ...[
                                        const Divider(height: 20),

                                        Text(
                                          "تفاصيل الطلب:",
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold),
                                        ),

                                        const SizedBox(height: 8),

                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment
                                              .start, // يتيح امتداد النص رأسياً
                                          children: [
                                            const SizedBox(width: 6),
                                            if (order['cart'] != null &&
                                                order['cart'].length > 0)
                                              Expanded(
                                                // ✅ يضمن احتواء النص مهما كان طوله
                                                child: Text(
                                                  "منتجات من المتجر",
                                                  style: const TextStyle(
                                                      color: Colors.blue),
                                                  softWrap:
                                                      true, // ✅ يسمح بالانتقال لأسطر جديدة
                                                  maxLines:
                                                      null, // ✅ عدد الأسطر غير محدود
                                                ),
                                              )
                                            else
                                              Expanded(
                                                // ✅ يضمن احتواء النص مهما كان طوله
                                                child: Text(
                                                  "${order['note'] ?? '-'}",
                                                  style: const TextStyle(
                                                      color: Colors.blue),
                                                  softWrap:
                                                      true, // ✅ يسمح بالانتقال لأسطر جديدة
                                                  maxLines:
                                                      null, // ✅ عدد الأسطر غير محدود
                                                ),
                                              ),
                                          ],
                                        ),

                                        const SizedBox(height: 10),

                                        /// ✅ عرض صور الطلب
                                        order!['orderImages'] != null &&
                                                (order!['orderImages'] as List)
                                                    .isNotEmpty
                                            ? GridView.builder(
                                                shrinkWrap: true,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                gridDelegate:
                                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 3,
                                                  crossAxisSpacing: 8,
                                                  mainAxisSpacing: 8,
                                                ),
                                                itemCount:
                                                    (order!['orderImages']
                                                            as List)
                                                        .length,
                                                itemBuilder: (context, index) {
                                                  final imgUrl =
                                                      order!['orderImages']
                                                          [index];
                                                  return ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: Image.network(
                                                      'https://eshtreeli-backend-2026-1.onrender.com$imgUrl',
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          const Icon(Icons
                                                              .broken_image),
                                                    ),
                                                  );
                                                },
                                              )
                                            : const Text('لا توجد صور للطلب',
                                                textAlign: TextAlign.right),

                                        const SizedBox(height: 15),

                                        /// ✅ زر تنفيذ الطلب
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            minimumSize:
                                                const Size(double.infinity, 45),
                                          ),
                                          onPressed: () async {
                                            final prefs =
                                                await SharedPreferences
                                                    .getInstance();
                                            final token =
                                                prefs.getString("token") ?? "";

                                            try {
                                              final response = await http.put(
                                                Uri.parse(
                                                  "https://eshtreeli-backend-2026-1.onrender.com/api/orders/${order['_id']}/accept",
                                                ),
                                                headers: {
                                                  "Content-Type":
                                                      "application/json",
                                                  "Authorization":
                                                      "Bearer $token",
                                                },
                                              );

                                              final result =
                                                  jsonDecode(response.body);

                                              if (response.statusCode == 200) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          "✅ تم قبول الطلب")),
                                                );

                                                // ✅ حذف الطلب من القائمة مباشرة
                                                setState(() {
                                                  data.removeAt(index);
                                                });
                                                // بعد الموافقة على الطلب بنجاح
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          const CaptainOrdersPage()),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          result["message"])),
                                                );
                                              }
                                            } catch (e) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        "❌ خطأ في الاتصال بالسيرفر")),
                                              );
                                            }
                                          },
                                          child: const Text(
                                              style: TextStyle(
                                                  color: Colors.white),
                                              "✅ قبول الطلب"),
                                        )
                                      ]
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
