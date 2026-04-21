import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:eshtreeli_captains_flutter/chat.dart';
import 'package:eshtreeli_captains_flutter/home.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';

class CaptainOrdersPage extends StatefulWidget {
  const CaptainOrdersPage({super.key});

  @override
  State<CaptainOrdersPage> createState() => _CaptainOrdersPageState();
}

class _CaptainOrdersPageState extends State<CaptainOrdersPage> {
  List orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCaptainOrders();
    checkPendingDialogs();
  }

  Future<void> cancelOrder(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";

    final url = Uri.parse(
      "https://eshtreeli-backend-2026-1.onrender.com/api/orders/$orderId/cancel-by-captain",
    );

    try {
      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم إلغاء الطلب")),
        );

        fetchCaptainOrders(); // تحديث القائمة
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ فشل: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ خطأ في الاتصال بالسيرفر")),
      );
    }
  }

  void confirmDelete(String orderId) {
    showDialog(
      context: context,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text("تأكيد الحذف"),
            content: const Text("هل أنت متأكد من حذف هذا الطلب؟"),
            actions: [
              TextButton(
                child: Text(
                  "إلغاء",
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text("حذف", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.pop(context);
                  cancelOrder(orderId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> checkPendingDialogs() async {
    final prefs = await SharedPreferences.getInstance();

    for (var order in orders) {
      bool pending = prefs.getBool("pendingDialog_${order['_id']}") ?? false;

      if (pending) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDeliveryDialog(order);
        });
        break;
      }
    }
  }

  Future<void> updateOrderStatus(String orderId, int newStatus) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";

    final url = Uri.parse(
        "https://eshtreeli-backend-2026-1.onrender.com/api/orders/$orderId/status"); // تأكد أن الـ endpoint صحيح

    try {
      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"status": newStatus}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ تم تحديث حالة الطلب: $newStatus")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ فشل: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ خطأ في الاتصال")),
      );
    }
  }

  void showDeliveryDialog(Map order) {
    TextEditingController deliveryController = TextEditingController();
    TextEditingController sumController = TextEditingController();

    bool needDeliveryPrice = (order['deliveryPrice'] == 0);

    showDialog(
      context: context,

      // ✅ يمنع الإغلاق بالضغط خارج الديالوج
      barrierDismissible: false,

      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl, // ✅ محاذاة يمين
          child: WillPopScope(
            // ✅ يمنع زر الرجوع من إغلاق الديالوج
            onWillPop: () async => false,

            child: AlertDialog(
              title: const Text(
                "يجب ملء التالية",
                textAlign: TextAlign.right,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ يظهر فقط إذا deliveryPrice = 0
                  if (needDeliveryPrice)
                    TextField(
                      controller: deliveryController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: "سعر التوصيل",
                      ),
                    ),

                  const SizedBox(height: 10),

                  // ✅ دائمًا يظهر sum
                  TextField(
                    controller: sumController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                        labelText: order["orderType"] == "car"
                            ? " مبلغ اضافي متفق عليه"
                            : "مجموع المشتريات "),
                  ),
                ],
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // لون الخلفية
                      foregroundColor: Colors.white, // لون النص والأيقونات
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text("حفظ وبدء التوصيل"),
                    onPressed: () async {
                      // ✅ تحقق من الإدخال
                      if (needDeliveryPrice &&
                          deliveryController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("❌ أدخل سعر التوصيل"),
                          ),
                        );
                        return;
                      }

                      if (sumController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(order["orderType"] == "car"
                                ? " مبلغ اضافي متفق عليه"
                                : "مجموع ❌ أدخل مجموع المشتريات"),
                          ),
                        );
                        return;
                      }

                      // ✅ تحقق من الأرقام فقط
                      int? deliveryPrice = needDeliveryPrice
                          ? int.tryParse(deliveryController.text)
                          : order['deliveryPrice'].round();

                      int? sum = int.tryParse(sumController.text);

                      if (deliveryPrice == null || sum == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("❌ أدخل أرقام صحيحة فقط"),
                          ),
                        );
                        return;
                      }

                      // ✅ حفظ أنه تم تعبئة البيانات (حتى لا يظهر مرة أخرى)
                      final prefs = await SharedPreferences.getInstance();
                      prefs.remove("pendingDialog_${order['_id']}");

                      // ✅ إغلاق الديالوج بعد نجاح الإدخال فقط
                      Navigator.pop(context);

                      // ✅ إرسال للباك اند
                      await updateOrderToDelivering(
                        order['_id'],
                        deliveryPrice,
                        sum,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> updateOrderToDelivering(
    String orderId,
    int deliveryPrice,
    int sum,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";

    final url = Uri.parse(
      "https://eshtreeli-backend-2026-1.onrender.com/api/orders/$orderId/delivering",
    );

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "deliveryPrice": deliveryPrice,
        "sum": sum,
        "status": 3,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم بدء التوصيل بنجاح")),
      );

      fetchCaptainOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ فشل: ${response.body}")),
      );
    }
  }

  Future<void> fetchCaptainOrders() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final url = Uri.parse(
        "https://eshtreeli-backend-2026-1.onrender.com/api/orders/captain");

    try {
      final response = await http.get(url, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          orders = data["orders"];
          isLoading = false;
        });

        // ✅ بعد تحميل الطلبات، تحقق من أي طلب بحاجة Dialog
        checkPendingDialogs();
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ: ${response.body}")),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ خطأ في الاتصال بالسيرفر")),
      );
    }
  }

  void callNumber(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void openMap(Map order) {
    final start = order['mapStartPoint'];
    final end = order['mapEndPoint'];
    if (start == null && end == null) return;

    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(
          startLat: parseCoord(start?['lat']),
          startLng: parseCoord(start?['lng']),
          endLat: parseCoord(end?['lat']),
          endLng: parseCoord(end?['lng']),
          startName: order['startLocation'] ?? "نقطة البداية",
          endName: order['endLocation'] ?? "نقطة النهاية",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: const Text(" طلبات قيد الانجاز")),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => home()), // الصفحة الرئيسية
              (route) => false, // يحذف كل الصفحات السابقة من الـ stack
            );
          },
        ),
      ),
      floatingActionButton: Material(
        elevation: 8,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (orders.isEmpty) return;

            final order = orders.first; // أول طلب ظاهر

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderChatPage(
                  orderId: order['_id'].toString(),
                  otherUserId: order['createdBy']['_id'],
                ),
              ),
            );
          },
          child: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchCaptainOrders,
              child: orders.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 150),
                        Center(
                            child: Text(
                                style: TextStyle(fontSize: 18),
                                "لا توجد طلبات")),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        final startLocation = order['startLocation'] ?? "";
                        final endLocation = order['endLocation'] ?? "";
                        // final userName = order['userName'] ?? "";
                        final userPhone = order['userPhone'] ?? "";
                        final extraPhone = order['extraPhone'] ?? "";
                        final deliveryPrice =
                            order['deliveryPrice'].round() ?? "";
                        final sum = order['sum'] ?? "";
                        final orderType = order['orderType'] ?? "";

                        final discount = order['discount'] ?? "";

                        final note = order['note'] ?? "";
                        final images =
                            List<String>.from(order['orderImages'] ?? []);
                        final startPoint = order['mapStartPoint'];
                        final endPoint = order['mapEndPoint'];

                        final hasMap = (startPoint != null &&
                                startPoint['lat'] != null &&
                                startPoint['lng'] != null) ||
                            (endPoint != null &&
                                endPoint['lat'] != null &&
                                endPoint['lng'] != null);

                        return Container(
                          margin: EdgeInsetsDirectional.only(bottom: 30),
                          child: Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.white,
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment
                                      .stretch, // يغطي كامل العرض
                                  textDirection:
                                      TextDirection.rtl, // كل شيء يمين
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            style: TextStyle(
                                                color: const Color.fromARGB(
                                                    255, 110, 110, 110),
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                            "تفاصيل الطلب"),
                                        if (order['status'] == 1)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                      horizontal: 16),
                                            ),
                                            onPressed: () {
                                              confirmDelete(order['_id']);
                                            },
                                            icon: const Icon(Icons.delete,
                                                color: Colors.white),
                                            label: const Text(
                                              "حذف الطلب",
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 25),
                                    if (startLocation.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 18, color: Colors.red),
                                          const SizedBox(width: 6),
                                          Text("من: $startLocation",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    const SizedBox(height: 15),
                                    if (endLocation.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.flag,
                                              size: 18, color: Colors.green),
                                          const SizedBox(width: 6),
                                          Text("إلى: $endLocation",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    const SizedBox(height: 20),
                                    if (order['cart'] != null &&
                                        (order['cart'] as List).isNotEmpty)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                              255, 238, 238, 238), // رمادي فاتح
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: ExpansionTile(
                                          //   tilePadding: EdgeInsets.zero,
                                          title: const Text(
                                            "تفاصيل الطلب",
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          children: [
                                            ...List.generate(
                                                order['cart'].length, (i) {
                                              final item = order['cart'][i];

                                              final productName =
                                                  item['productName'] ?? '';
                                              final subName =
                                                  item['subProductName'] ?? '';
                                              final qty = item['quantity'] ?? 1;
                                              final price = item['price'];
                                              final extras =
                                                  item['extras'] ?? [];
                                              final note = item['note'] ?? '';
                                              final image = item['image'] ?? '';

                                              return Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 8),
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (image.isNotEmpty)
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: Image.network(
                                                          "$image",
                                                          width: 55,
                                                          height: 55,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "$productName $subName",
                                                            textAlign:
                                                                TextAlign.right,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          Text(
                                                            "الكمية: $qty",
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        12),
                                                            textAlign:
                                                                TextAlign.right,
                                                          ),
                                                          if (price != null)
                                                            Text(
                                                              "السعر: $price ₪",
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          12),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          if (extras.isNotEmpty)
                                                            Text(
                                                              "الإضافات: ${extras.map((e) => e['name']).join(", ")}",
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          if (note.isNotEmpty &&
                                                              note != "")
                                                            Text(
                                                              " $note",
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 15),
                                    if (note.isNotEmpty)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.note,
                                              size: 16, color: Colors.orange),
                                          const SizedBox(width: 6),
                                          Expanded(
                                              child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (order['cart'] != null &&
                                                      order['cart'].length >
                                                          0 ||
                                                  order['orderType'] == "car")
                                                const Text(
                                                  "ملاحظات: ",
                                                  style: TextStyle(),
                                                )
                                              else
                                                const Text(
                                                  "الطلب: ",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              Expanded(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(0),
                                                  decoration: BoxDecoration(
                                                    color: const Color.fromARGB(
                                                        255,
                                                        255,
                                                        255,
                                                        255), // رمادي فاتح
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    "$note",
                                                    style: TextStyle(
                                                      color:
                                                          const Color.fromARGB(
                                                              255, 0, 102, 5),
                                                      fontSize: order['cart'] !=
                                                                      null &&
                                                                  order['cart']
                                                                          .length >
                                                                      0 ||
                                                              order['orderType'] ==
                                                                  "car"
                                                          ? 14
                                                          : 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    softWrap: true,
                                                    maxLines: null,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ))
                                        ],
                                      ),
                                    SizedBox(
                                      height: 15,
                                    ),
                                    if (images.isNotEmpty)
                                      SizedBox(
                                        height: 100,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: images.length,
                                          itemBuilder: (context, imgIndex) {
                                            final img = images[imgIndex];
                                            return Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 8.0),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (_) => Dialog(
                                                        backgroundColor:
                                                            const Color
                                                                .fromARGB(255,
                                                                255, 255, 255),
                                                        insetPadding:
                                                            EdgeInsets.zero,
                                                        child: GestureDetector(
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                  context),
                                                          child: Image.network(
                                                            "https://eshtreeli-backend-2026-1.onrender.com$img",
                                                            fit: BoxFit.contain,
                                                            errorBuilder:
                                                                (context, error,
                                                                    stackTrace) {
                                                              return const SizedBox(
                                                                height: 200,
                                                                child: Center(
                                                                  child: Text(
                                                                    "الصورة غالبا مؤقتة والان غير متاحة",
                                                                    style: TextStyle(
                                                                        color: Color.fromARGB(
                                                                            255,
                                                                            0,
                                                                            0,
                                                                            0),
                                                                        fontSize:
                                                                            16),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    child: Image.network(
                                                      "https://eshtreeli-backend-2026-1.onrender.com$img",
                                                      width: 100,
                                                      height: 100,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return Container(
                                                          width: 100,
                                                          height: 100,
                                                          alignment:
                                                              Alignment.center,
                                                          color: Colors
                                                              .grey.shade200,
                                                          child: const Text(
                                                            "لا يوجد صورة",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .black54,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ));
                                          },
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                    Column(
                                      children: [
                                        InkWell(
                                          onTap: () => callNumber(userPhone),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.phone,
                                                  size: 16, color: Colors.teal),
                                              const SizedBox(width: 6),
                                              Text(
                                                "الرقم: ",
                                              ),
                                              Text(
                                                " $userPhone",
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          height: 10,
                                        ),
                                        if (extraPhone.isNotEmpty)
                                          InkWell(
                                            onTap: () => callNumber(extraPhone),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.phone_android,
                                                    size: 16,
                                                    color: Colors.teal),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "رقم إضافي:",
                                                ),
                                                Text(
                                                  " $extraPhone",
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 15,
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.money,
                                            size: 16, color: Colors.teal),
                                        const SizedBox(width: 6),
                                        const Text("سعر التوصيل: "),
                                        const SizedBox(width: 6),
                                        if (deliveryPrice != 0)
                                          Text(
                                            "$deliveryPrice",
                                            style: const TextStyle(
                                              color:
                                                  Color.fromARGB(255, 0, 0, 0),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        else
                                          Expanded(
                                            child: Text(
                                              "انت من سيحدد سعر التوصيل ",
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                    255, 255, 0, 0),
                                                fontWeight: FontWeight.bold,
                                              ),
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 5,
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.money,
                                            size: 16, color: Colors.teal),
                                        const SizedBox(width: 6),
                                        Text(order["orderType"] == "car"
                                            ? " مبلغ اضافي متفق عليه: "
                                            : " مجموع المشتريات :"),
                                        const SizedBox(width: 6),
                                        Text(
                                          "$sum",
                                          style: const TextStyle(
                                              color:
                                                  Color.fromARGB(255, 0, 48, 2),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.money,
                                            size: 16, color: Colors.teal),
                                        const SizedBox(width: 6),
                                        const Text("الخصم: "),
                                        const SizedBox(width: 6),
                                        Text(
                                          "${discount.round()}",
                                          style: const TextStyle(
                                              color:
                                                  Color.fromARGB(255, 0, 48, 2),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                        )
                                      ],
                                    ),
                                    SizedBox(
                                      height: 15,
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.money,
                                            size: 16, color: Colors.teal),
                                        const SizedBox(width: 6),
                                        const Text("المجموع النهائي: "),
                                        const SizedBox(width: 6),
                                        Text(
                                          "${(sum + deliveryPrice - discount).round()}",
                                          style: const TextStyle(
                                              color: Color.fromARGB(
                                                  255, 255, 0, 0),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    if (hasMap)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () => openMap(order),
                                        icon: const Icon(Icons.map,
                                            color: Colors.white),
                                        label: const Text("عرض الخريطة",
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ),
                                    SizedBox(
                                      height: 15,
                                    ),
                                    StatefulBuilder(
                                      builder: (context, setStateCard) {
                                        int status = order['status'] ?? 1;

                                        // النص
                                        String buttonText = (status == 1)
                                            ? "اضغط للتوصيل"
                                            : (status == 3)
                                                ? "اضغط للإنهاء"
                                                : "تم الانتهاء";

                                        // اللون
                                        Color buttonColor = (status == 1)
                                            ? Colors.green
                                            : (status == 3)
                                                ? Colors.red
                                                : Colors.grey;

                                        // إذا الحالة 4 نخفي الزر
                                        if (status == 4) return SizedBox();

                                        return ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: buttonColor,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                          child: Text(
                                            buttonText,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          onPressed: () async {
                                            int newStatus =
                                                (status == 1) ? 3 : 4;

                                            // تحديث فوري بالشاشة
                                            setStateCard(() {
                                              order['status'] = newStatus;
                                            });
                                            if (status == 1) {
                                              final prefs =
                                                  await SharedPreferences
                                                      .getInstance();

                                              // خزّن أن هذا الطلب بحاجة تعبئة
                                              prefs.setBool(
                                                  "pendingDialog_${order['_id']}",
                                                  true);

                                              showDeliveryDialog(order);
                                            }

                                            final prefs =
                                                await SharedPreferences
                                                    .getInstance();
                                            final token =
                                                prefs.getString("token") ?? "";

                                            final url = Uri.parse(
                                              "https://eshtreeli-backend-2026-1.onrender.com/api/orders/${order['_id']}/status",
                                            );

                                            try {
                                              final response = await http.put(
                                                url,
                                                headers: {
                                                  "Content-Type":
                                                      "application/json",
                                                  "Authorization":
                                                      "Bearer $token",
                                                },
                                                body: jsonEncode(
                                                    {"status": newStatus}),
                                              );

                                              if (response.statusCode == 200) {
                                                // ✅ SnackBar نجاح
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      newStatus == 3
                                                          ? "✅ تم بدء التوصيل"
                                                          : "✅ تم إنهاء الطلب بنجاح",
                                                    ),
                                                    duration: const Duration(
                                                        seconds: 2),
                                                  ),
                                                );
                                              } else {
                                                // ❌ SnackBar فشل
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        "❌ فشل التحديث: ${response.body}"),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              // ❌ SnackBar خطأ اتصال
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      "❌ خطأ في الاتصال بالسيرفر"),
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                                    SizedBox(
                                      height: 40,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ─── مراحل الملاحة ───────────────────────────────────────
enum _NavPhase {
  toPickup, // المرحلة 1: الكابتن ذاهب لمكان الانطلاق
  toDropoff, // المرحلة 2: الكابتن ذاهب لنقطة الوصول
}

class MapPage extends StatefulWidget {
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final String startName;
  final String endName;

  const MapPage({
    super.key,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    required this.startName,
    required this.endName,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  List<LatLng> routePoints = [];
  LatLng? start;
  LatLng? end;

  // ─── GPS ────────────────────────────────────────────────
  LatLng? _currentLocation;
  double _currentHeading = 0.0;
  double _currentSpeed = 0.0;
  StreamSubscription<Position>? _positionSub;

  // ─── Navigation State ───────────────────────────────────
  bool _isNavigating = false;
  bool _is3DMode = false;
  bool _followUser = false;
  _NavPhase _phase = _NavPhase.toPickup;

  // منع تكرار معالجة الوصول عند البقاء في نطاق 50م
  bool _arrivalHandled = false;

  // مسافة اعتبار الوصول = 50 متر
  static const double _arrivalThresholdMeters = 50;

  final MapController _mapController = MapController();
  final PopupController popupController = PopupController();

  // ─── Animation للـ 3D ───────────────────────────────────
  late AnimationController _tiltAnimController;
  late Animation<double> _tiltAnimation;
  double _currentTilt = 0.0;

  @override
  void initState() {
    super.initState();

    _tiltAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _tiltAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _tiltAnimController, curve: Curves.easeInOut),
    )..addListener(() {
        setState(() => _currentTilt = _tiltAnimation.value);
      });

    if (widget.startLat != null && widget.startLng != null) {
      start = LatLng(widget.startLat!, widget.startLng!);
    }
    if (widget.endLat != null && widget.endLng != null) {
      end = LatLng(widget.endLat!, widget.endLng!);
    }

    _requestPermissionAndStartTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _tiltAnimController.dispose();
    super.dispose();
  }

  // ─── صلاحيات ────────────────────────────────────────────
  Future<void> _requestPermissionAndStartTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _showPermissionDialog();
      return;
    }
    _startLocationStream();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("صلاحية الموقع مطلوبة"),
        content: const Text("يرجى تفعيل صلاحية الموقع من إعدادات التطبيق"),
        actions: [
          TextButton(
            onPressed: () => Geolocator.openAppSettings(),
            child: const Text("فتح الإعدادات"),
          ),
        ],
      ),
    );
  }

  // ─── GPS Stream ─────────────────────────────────────────
  void _startLocationStream() async {
    // موقع فوري أولاً
    try {
      final Position initial = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(initial.latitude, initial.longitude);
        _currentSpeed = initial.speed * 3.6;
        if (initial.heading >= 0) _currentHeading = initial.heading;
      });
    } catch (e) {
      debugPrint("INITIAL POSITION ERROR: $e");
    }

    // ثم بث مستمر
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentSpeed = position.speed * 3.6;
        if (position.heading >= 0) _currentHeading = position.heading;
      });

      if (_isNavigating) {
        _checkArrival();
        if (_followUser) _moveCamera();
      }
    });
  }

  // ─── تحميل المسار حسب المرحلة ────────────────────────────
  Future<void> _loadRoute(_NavPhase phase) async {
    LatLng? from;
    LatLng? to;

    if (phase == _NavPhase.toPickup) {
      from = _currentLocation;
      to = start;
    } else {
      // إذا start == null استخدم الموقع الحالي كنقطة انطلاق
      from = start ?? _currentLocation;
      to = end;
    }

    if (from == null || to == null) return;

    final url = "https://router.project-osrm.org/route/v1/driving/"
        "${from.longitude},${from.latitude};"
        "${to.longitude},${to.latitude}"
        "?overview=full&geometries=geojson";

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      final coords = data["routes"][0]["geometry"]["coordinates"];
      if (!mounted) return;
      setState(() {
        routePoints = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
      });
    } catch (e) {
      debugPrint("ROUTE ERROR: $e");
    }
  }

  // ─── فحص الوصول للنقطة المستهدفة ────────────────────────
  void _checkArrival() {
    if (_currentLocation == null) return;
    if (_arrivalHandled) return; // منع التكرار

    final target = _phase == _NavPhase.toPickup ? start : end;
    if (target == null) return;

    final dist = const Distance().as(
      LengthUnit.Meter,
      _currentLocation!,
      target,
    );

    if (dist <= _arrivalThresholdMeters) {
      setState(() => _arrivalHandled = true);

      if (_phase == _NavPhase.toPickup) {
        if (end != null) {
          // وجهة نهائية موجودة → انتقل للمرحلة الثانية
          setState(() {
            _phase = _NavPhase.toDropoff;
            _arrivalHandled = false; // أعد التفعيل للمرحلة الجديدة
          });
          _loadRoute(_NavPhase.toDropoff);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "✅ وصلت لـ ${widget.startName}\n🧭 الآن توجّه إلى ${widget.endName}"),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // لا توجد وجهة نهائية → أوقف الملاحة
          _stopNavigation();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ وصلت إلى ${widget.startName}"),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // وصل للوجهة النهائية
        _stopNavigation();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🎉 وصلت إلى ${widget.endName}"),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ─── حركة الكاميرا ──────────────────────────────────────
  void _moveCamera() {
    if (_currentLocation == null) return;
    final zoom = _is3DMode ? 18.5 : 16.0;
    _mapController.move(_currentLocation!, zoom);
    if (_is3DMode || _followUser) {
      _mapController.rotate(-_currentHeading);
    }
  }

  // ─── بدء الملاحة ────────────────────────────────────────
  void _startNavigation() {
    // تحديد المرحلة الأولى حسب البيانات المتاحة
    final initialPhase =
        start != null ? _NavPhase.toPickup : _NavPhase.toDropoff;

    // الوجهة الأولى للعرض في الـ SnackBar
    final firstDest = start != null ? widget.startName : widget.endName;

    setState(() {
      _isNavigating = true;
      _followUser = true;
      _phase = initialPhase;
      _arrivalHandled = false;
    });

    _loadRoute(initialPhase);
    _moveCamera();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🧭 توجّه إلى $firstDest"),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // ─── تبديل 3D ───────────────────────────────────────────
  void _toggle3DMode() {
    setState(() => _is3DMode = !_is3DMode);

    if (_is3DMode) {
      _tiltAnimController.forward();
      setState(() => _followUser = true);
      _moveCamera();
    } else {
      _tiltAnimController.reverse();
      _mapController.rotate(0);
    }
  }

  // ─── إيقاف الملاحة ──────────────────────────────────────
  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _followUser = false;
      _is3DMode = false;
      _phase = _NavPhase.toPickup;
      _arrivalHandled = false;
    });
    _tiltAnimController.reverse();
    _mapController.rotate(0);
  }

  // ─── المسار المتبقي ──────────────────────────────────────
  List<LatLng> _getRemainingRoute() {
    if (_currentLocation == null || routePoints.isEmpty) return routePoints;

    double minDist = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < routePoints.length; i++) {
      final d = const Distance().as(
        LengthUnit.Meter,
        _currentLocation!,
        routePoints[i],
      );
      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }
    return routePoints.sublist(closestIndex);
  }

  @override
  Widget build(BuildContext context) {
    LatLng center = const LatLng(32.2, 35.25);
    LatLngBounds? bounds;

    if (start != null && end != null) {
      bounds = LatLngBounds.fromPoints([start!, end!]);
      center = bounds.center;
    } else if (start != null) {
      center = start!;
    } else if (end != null) {
      center = end!;
    }

    final List<Marker> markers = [];

    if (start != null) {
      markers.add(Marker(
        point: start!,
        width: 44,
        height: 44,
        child: const Icon(Icons.location_on, color: Colors.red, size: 44),
      ));
    }
    if (end != null) {
      markers.add(Marker(
        point: end!,
        width: 44,
        height: 44,
        child: const Icon(Icons.flag, color: Colors.green, size: 44),
      ));
    }
    if (_currentLocation != null) {
      markers.add(Marker(
        point: _currentLocation!,
        width: 56,
        height: 56,
        child: _CaptainMarker(heading: _currentHeading),
      ));
    }

    final remainingRoute = _isNavigating ? _getRemainingRoute() : routePoints;

    final currentDestName =
        _phase == _NavPhase.toPickup ? widget.startName : widget.endName;

    // ─── الخريطة ────────────────────────────────────────
    Widget mapWidget = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        initialCameraFit: bounds != null && !_isNavigating
            ? CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(60),
              )
            : null,
        onTap: (_, __) {
          popupController.hideAllPopups();
          if (_followUser) setState(() => _followUser = false);
        },
        interactionOptions: InteractionOptions(
          flags: _is3DMode
              ? InteractiveFlag.pinchZoom | InteractiveFlag.drag
              : InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: "https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",
          userAgentPackageName: "com.eshtreeli.captains",
          maxZoom: 19,
        ),
        if (routePoints.isNotEmpty && _isNavigating)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 8,
                color: Colors.blue.withOpacity(0.2),
              ),
            ],
          ),
        if (remainingRoute.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: remainingRoute,
                strokeWidth: 8,
                color:
                    _phase == _NavPhase.toPickup ? Colors.orange : Colors.blue,
                borderColor: Colors.white,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        PopupMarkerLayer(
          options: PopupMarkerLayerOptions(
            popupController: popupController,
            markers: markers,
            popupDisplayOptions: PopupDisplayOptions(
              builder: (context, marker) {
                String text = "";
                if (start != null && marker.point == start) {
                  text = "📍 ${widget.startName}";
                } else if (end != null && marker.point == end) {
                  text = "🏁 ${widget.endName}";
                } else if (_currentLocation != null &&
                    marker.point == _currentLocation) {
                  text = "🚗 موقعك\n${_currentSpeed.toStringAsFixed(1)} km/h";
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(text, style: const TextStyle(fontSize: 14)),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );

    // ─── تأثير الـ 3D عبر Matrix4 Perspective ────────────
    // يعطي انطباع العمق والميل للأمام مثل Google Maps
    if (_currentTilt > 0) {
      final tiltAngle = _currentTilt * 0.45; // max ~25 درجة ميل
      mapWidget = Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0008)
          ..rotateX(tiltAngle),
        child: mapWidget,
      );
    }

    return Scaffold(
      appBar: _is3DMode
          ? null
          : AppBar(
              title: Text(
                _isNavigating
                    ? (_phase == _NavPhase.toPickup
                        ? "إلى: ${widget.startName}"
                        : "إلى: ${widget.endName}")
                    : "الموقع على الخريطة",
              ),
              actions: [
                if (_currentLocation != null && _isNavigating)
                  IconButton(
                    icon: Icon(
                      _followUser ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: _followUser ? Colors.blue : null,
                    ),
                    onPressed: () {
                      setState(() => _followUser = !_followUser);
                      if (_followUser) _moveCamera();
                    },
                    tooltip: "تتبع موقعي",
                  ),
              ],
            ),
      body: Stack(
        children: [
          mapWidget,

          // شريط معلومات الملاحة العلوي
          if (_isNavigating && _currentLocation != null)
            Positioned(
              top: _is3DMode ? 40 : 0,
              left: 0,
              right: 0,
              child: _NavigationInfoBar(
                speed: _currentSpeed,
                destination: currentDestName,
                phase: _phase,
                remainingPoints: remainingRoute,
              ),
            ),

          // Badge المرحلة
          if (_isNavigating)
            Positioned(
              top: _is3DMode ? 130 : 90,
              left: 140,
              child: _PhaseBadge(phase: _phase),
            ),

          // أزرار التحكم
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _NavigationControls(
              isNavigating: _isNavigating,
              is3DMode: _is3DMode,
              followUser: _followUser,
              hasLocation: _currentLocation != null,
              onStartNavigation: _startNavigation,
              onStopNavigation: _stopNavigation,
              onToggle3D: _toggle3DMode,
              onCenterUser: () {
                setState(() => _followUser = true);
                _moveCamera();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ماركر الكابتن ──────────────────────────────────────
class _CaptainMarker extends StatelessWidget {
  final double heading;
  const _CaptainMarker({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * (math.pi / 180),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.withOpacity(0.15),
          border: Border.all(color: Colors.blue, width: 2.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
            ),
            const Positioned(
              top: 5,
              child: Icon(Icons.navigation, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── شريط معلومات الملاحة ───────────────────────────────
class _NavigationInfoBar extends StatelessWidget {
  final double speed;
  final String destination;
  final _NavPhase phase;
  final List<LatLng> remainingPoints;

  const _NavigationInfoBar({
    required this.speed,
    required this.destination,
    required this.phase,
    required this.remainingPoints,
  });

  double get _remainingDistance {
    if (remainingPoints.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < remainingPoints.length - 1; i++) {
      total += const Distance().as(
        LengthUnit.Meter,
        remainingPoints[i],
        remainingPoints[i + 1],
      );
    }
    return total;
  }

  String get _distanceText {
    final d = _remainingDistance;
    if (d < 1000) return "${d.toStringAsFixed(0)} م";
    return "${(d / 1000).toStringAsFixed(1)} كم";
  }

  @override
  Widget build(BuildContext context) {
    final color = phase == _NavPhase.toPickup ? Colors.orange : Colors.blue;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // السرعة
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speed.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Text("km/h",
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          const SizedBox(width: 14),
          // الوجهة والمسافة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  destination,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.route, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      "متبقي: $_distanceText",
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badge المرحلة ───────────────────────────────────────
class _PhaseBadge extends StatelessWidget {
  final _NavPhase phase;
  const _PhaseBadge({required this.phase});

  @override
  Widget build(BuildContext context) {
    final isPickup = phase == _NavPhase.toPickup;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            isPickup ? Colors.orange : const Color.fromARGB(255, 16, 211, 26),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPickup ? Icons.person_pin_circle : Icons.flag,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isPickup ? "جاري الاستلام" : "جاري التوصيل",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── أزرار التحكم ────────────────────────────────────────
class _NavigationControls extends StatelessWidget {
  final bool isNavigating;
  final bool is3DMode;
  final bool followUser;
  final bool hasLocation;
  final VoidCallback onStartNavigation;
  final VoidCallback onStopNavigation;
  final VoidCallback onToggle3D;
  final VoidCallback onCenterUser;

  const _NavigationControls({
    required this.isNavigating,
    required this.is3DMode,
    required this.followUser,
    required this.hasLocation,
    required this.onStartNavigation,
    required this.onStopNavigation,
    required this.onToggle3D,
    required this.onCenterUser,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isNavigating) ...[
          FloatingActionButton.small(
            heroTag: "btn3d",
            backgroundColor: is3DMode ? Colors.orange : Colors.white,
            foregroundColor: is3DMode ? Colors.white : Colors.orange,
            elevation: 4,
            onPressed: onToggle3D,
            child: Text(
              is3DMode ? "2D" : "3D",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          if (!followUser) ...[
            FloatingActionButton.small(
              heroTag: "btnCenter",
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              elevation: 4,
              onPressed: onCenterUser,
              child: const Icon(Icons.my_location),
            ),
            const SizedBox(width: 8),
          ],
          FloatingActionButton.extended(
            heroTag: "btnStop",
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.close),
            label: const Text("إيقاف"),
            onPressed: onStopNavigation,
          ),
        ] else ...[
          FloatingActionButton.extended(
            heroTag: "btnStart",
            backgroundColor: hasLocation ? Colors.blue : Colors.grey,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.navigation),
            label: Text(
              hasLocation ? "ابدأ الملاحة" : "جاري تحديد الموقع...",
            ),
            onPressed: hasLocation ? onStartNavigation : null,
          ),
        ],
      ],
    );
  }
}
