import 'dart:convert';
import 'package:eshtreeli_captains_flutter/IncompleteOrdersPage.dart';
import 'package:eshtreeli_captains_flutter/chat.dart';
import 'package:eshtreeli_captains_flutter/chatAdmin.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ================= MODEL =================
class NotificationModel {
  final String title;
  final String body;
  final String userName;
  final String role;
  final String orderId;
  final DateTime createdAt;
  final List<String> images;

  final String? roomId;
  final String? senderId;

  NotificationModel({
    required this.title,
    required this.body,
    required this.userName,
    required this.role,
    required this.createdAt,
    required this.images,
    required this.orderId,
    this.roomId,
    this.senderId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      title: json['title']?.toString() ?? "بدون عنوان",
      body: json['body']?.toString() ?? "بدون نص",
      userName: json['user']?['name']?.toString() ?? "مجهول",
      role: json['role']?.toString() ?? "user",
      orderId: json['orderId']?.toString() ?? "",
      roomId: json['roomId']?.toString(),
      senderId: json['senderId']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? "") ??
          DateTime.now(),
      images:
          (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

// ================= PAGE =================
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('id') ?? "";

    final res = await http.get(
      Uri.parse("http://192.168.1.6:5000/api/notifications/$userId"),
      headers: {"Content-Type": "application/json"},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List list = data['notifications'] ?? [];

      setState(() {
        notifications = list.map((e) => NotificationModel.fromJson(e)).toList();
        loading = false;
      });
    }
  }

  String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "الآن";
    if (diff.inHours < 1) return "منذ ${diff.inMinutes} دقيقة";
    if (diff.inDays < 1) return "منذ ${diff.inHours} ساعة";
    return "منذ ${diff.inDays} يوم";
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text("الإشعارات"), centerTitle: true),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : notifications.isEmpty
                ? const Center(child: Text("لا توجد إشعارات"))
                : RefreshIndicator(
                    onRefresh: loadNotifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: notifications.length,
                      itemBuilder: (context, i) {
                        final noti = notifications[i];

                        return InkWell(
                          onTap: () {
                            final orderId = noti.orderId;

                            if (orderId != null &&
                                orderId.toString().trim().isNotEmpty &&
                                orderId.toString() != "null") {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CaptainOrdersPage(),
                                ),
                              );
                            } else {
                              if (noti.role != 'admin') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderChatPage(
                                      orderId: noti.roomId ?? "",
                                      otherUserId: noti.senderId ?? "",
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatPage(),
                                  ),
                                );
                              }
                            }
                          },
                          child: Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(
                                        noti.role == "admin"
                                            ? Icons.support_agent
                                            : Icons.delivery_dining,
                                        size: 25,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(noti.title),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(noti.body),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        timeAgo(noti.createdAt),
                                        style: const TextStyle(
                                            color: Colors.redAccent),
                                      ),
                                    ],
                                  ),
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
