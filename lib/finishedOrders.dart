import 'dart:convert';
import 'package:eshtreeli_captains_flutter/home.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class finishedOrders extends StatefulWidget {
  const finishedOrders({super.key});

  @override
  State<finishedOrders> createState() => _finishedOrdersState();
}

class _finishedOrdersState extends State<finishedOrders> {
  List orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCaptainOrders();
    checkPendingDialogs();
  }

  String formatDateTime(String dateString) {
    DateTime dt = DateTime.parse(dateString);

    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}  "
        "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ";
  }

  Future<void> checkPendingDialogs() async {}

  Future<void> fetchCaptainOrders() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final url = Uri.parse(
        "https://eshtreeli-backend-2026-1.onrender.com/api/orders/captainfinish");

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(" طلباتك المنجزة - العدد:${orders.length} "),
        ),
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
                        final deliveryPrice = order['deliveryPrice'] ?? "";
                        final sum = order['sum'] ?? "";

                        final note = order['note'] ?? "";
                        final images =
                            List<String>.from(order['orderImages'] ?? []);
                        final hasMap = order['mapStartPoint'] != null ||
                            order['mapEndPoint'] != null;

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
                                        Text(
                                            style: TextStyle(
                                                color: const Color.fromARGB(
                                                    255, 255, 0, 0),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                            formatDateTime(order['createdAt'])),
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
                                    SizedBox(
                                      width: 20,
                                    ),
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
                                              const Text(
                                                "الطلب: ",
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              Expanded(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: const Color.fromARGB(
                                                        255,
                                                        250,
                                                        250,
                                                        250), // رمادي فاتح
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    "$note",
                                                    style: const TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 0, 102, 5),
                                                      fontSize: 16,
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
                                                            Colors.black,
                                                        insetPadding:
                                                            EdgeInsets.zero,
                                                        child: GestureDetector(
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                  context),
                                                          child: Image.network(
                                                            "https://eshtreeli-backend-2026-1.onrender.com$img",
                                                            fit: BoxFit.contain,
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
                                              color: Colors.green,
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
                                        const Text("مجموع المشتريات: "),
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
                                          "${sum + deliveryPrice}",
                                          style: const TextStyle(
                                              color: Color.fromARGB(
                                                  255, 255, 0, 0),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        )
                                      ],
                                    ),
                                    SizedBox(
                                      height: 25,
                                    )
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
