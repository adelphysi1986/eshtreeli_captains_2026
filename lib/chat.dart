import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class OrderChatPage extends StatefulWidget {
  final String orderId;
  final String otherUserId;

  const OrderChatPage({
    super.key,
    required this.orderId,
    required this.otherUserId,
  });

  @override
  State<OrderChatPage> createState() => _OrderChatPageState();
}

class _OrderChatPageState extends State<OrderChatPage> {
  IO.Socket? socket;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController controller = TextEditingController();
  final ScrollController scroll = ScrollController();

  final AudioRecorder _record = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  String? _currentlyPlayingUrl;

  bool isRecording = false;

  List<Map<String, dynamic>> messages = [];

  String myId = "";
  bool typing = false;

  @override
  void initState() {
    super.initState();
    _initChat();

    _player.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });

    _player.onPlayerStateChanged.listen((state) {
      setState(() => _playerState = state);
      if (state == PlayerState.completed) {
        _position = Duration.zero;
        _currentlyPlayingUrl = null;
      }
    });
  }

  Future<void> _pickAndSendImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    var request = http.MultipartRequest(
      "POST",
      Uri.parse(
          "https://eshtreeli-backend-2026-1.onrender.com/api/order-chat/upload-image"),
    );

    request.headers['Authorization'] = "Bearer $token";

    request.fields['orderId'] = widget.orderId;
    request.fields['senderId'] = myId;
    request.fields['receiverId'] = widget.otherUserId;

    request.files.add(
      await http.MultipartFile.fromPath(
        "image",
        image.path,
      ),
    );

    await request.send();
  }

  Future<void> _initChat() async {
    final prefs = await SharedPreferences.getInstance();
    myId = prefs.getString("id") ?? "";

    socket = IO.io(
      "https://eshtreeli-backend-2026-1.onrender.com",
      IO.OptionBuilder().setTransports(['websocket']).build(),
    );

    socket?.connect();

    socket?.emit("joinOrderRoom", {"orderId": widget.orderId});

    socket?.on("receiveOrderMessage", (data) {
      setState(() {
        messages.add(Map<String, dynamic>.from(data));
      });
      _scrollBottom();
    });

    socket?.on("typing", (_) => setState(() => typing = true));
    socket?.on("stopTyping", (_) => setState(() => typing = false));

    await _loadOld();
  }

  Future<void> _loadOld() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    final res = await http.get(
      Uri.parse(
          "https://eshtreeli-backend-2026-1.onrender.com/api/order-chat/${widget.orderId}"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      setState(() {
        messages = List<Map<String, dynamic>>.from(data["messages"]);
      });

      _scrollBottom();
    }
  }

  void _send() {
    if (controller.text.trim().isEmpty) return;

    socket?.emit("sendOrderMessage", {
      "orderId": widget.orderId,
      "senderId": myId,
      "receiverId": widget.otherUserId,
      "message": controller.text.trim(),
    });

    controller.clear();
  }

  Future<void> _startRecording() async {
    if (!await _record.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/order_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _record.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );

    setState(() => isRecording = true);
  }

  Future<void> _stopRecording() async {
    final path = await _record.stop();
    setState(() => isRecording = false);
    if (path == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    var request = http.MultipartRequest(
      "POST",
      Uri.parse(
          "https://eshtreeli-backend-2026-1.onrender.com/api/order-chat/upload-audio"),
    );

    request.headers['Authorization'] = "Bearer $token";
    request.fields['orderId'] = widget.orderId;
    request.fields['senderId'] = myId;
    request.fields['receiverId'] = widget.otherUserId;

    request.files.add(await http.MultipartFile.fromPath(
      "audio",
      path,
      contentType: MediaType("audio", "mp4"),
    ));

    await request.send();
  }

  Future<void> _playAudio(String url) async {
    try {
      final fullUrl = "https://eshtreeli-backend-2026-1.onrender.com$url";

      if (_currentlyPlayingUrl == fullUrl &&
          _playerState == PlayerState.playing) {
        await _player.pause();
        return;
      }

      if (_currentlyPlayingUrl == fullUrl &&
          _playerState == PlayerState.paused) {
        await _player.resume();
        return;
      }

      await _player.stop();

      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode != 200) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_order_audio.m4a');
      await file.writeAsBytes(response.bodyBytes);

      _currentlyPlayingUrl = fullUrl;
      _position = Duration.zero;

      await _player.play(DeviceFileSource(file.path));
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.jumpTo(scroll.position.maxScrollExtent + 80);
      }
    });
  }

  @override
  void dispose() {
    socket?.dispose();
    controller.dispose();
    scroll.dispose();
    _player.dispose();
    _record.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("محادثة الطلب"),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(10),
                itemCount: messages.length,
                itemBuilder: (c, i) {
                  final m = messages[i];
                  final isMe = m["senderId"] == myId;

                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(5),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * .7),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.green : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: m["type"] == "image"
                          ? GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: Image.network(
                                      "https://eshtreeli-backend-2026-1.onrender.com${m["imageUrl"]}",
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const SizedBox(
                                          height: 200,
                                          child: Center(
                                            child: Text(
                                                "الصورة غالبا مؤقتة والان هي غير متاحة"),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  "https://eshtreeli-backend-2026-1.onrender.com${m["imageUrl"]}",
                                  width: 160,
                                  height: 160,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 160,
                                      height: 160,
                                      color: Colors.grey.shade300,
                                      child: const Center(
                                        child: Icon(Icons.image_not_supported,
                                            size: 40),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          : m["type"] == "audio"
                              ? Builder(
                                  builder: (_) {
                                    final fullUrl =
                                        "https://eshtreeli-backend-2026-1.onrender.com${m["audioUrl"]}";
                                    final isCurrent =
                                        _currentlyPlayingUrl == fullUrl;

                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                height: 12,
                                              ),
                                              Directionality(
                                                textDirection:
                                                    TextDirection.ltr,
                                                child: Slider(
                                                  min: 0,
                                                  max: isCurrent
                                                      ? (_duration.inMilliseconds ==
                                                              0
                                                          ? 1
                                                          : _duration
                                                              .inMilliseconds
                                                              .toDouble())
                                                      : 1,
                                                  value: isCurrent
                                                      ? _position.inMilliseconds
                                                          .toDouble()
                                                          .clamp(
                                                              0,
                                                              _duration
                                                                  .inMilliseconds
                                                                  .toDouble())
                                                      : 0,
                                                  onChanged: isCurrent
                                                      ? (value) async {
                                                          await _player.seek(
                                                            Duration(
                                                                milliseconds:
                                                                    value
                                                                        .toInt()),
                                                          );
                                                        }
                                                      : null,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    isCurrent
                                                        ? _formatDuration(
                                                            _position)
                                                        : "00:00",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isMe
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          iconSize: 35,
                                          icon: Icon(
                                            isCurrent &&
                                                    _playerState ==
                                                        PlayerState.playing
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: isMe
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                          onPressed: () {
                                            _playAudio(m["audioUrl"]);
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                )
                              : Text(
                                  m["message"] ?? "",
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                    fontSize: 15,
                                  ),
                                ),
                    ),
                  );
                },
              ),
            ),
            if (typing)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text("يكتب الآن..."),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  IconButton(
                    iconSize: 30,
                    icon: Icon(
                      isRecording ? Icons.stop : Icons.mic,
                      color: isRecording ? Colors.red : Colors.green,
                    ),
                    onPressed: isRecording ? _stopRecording : _startRecording,
                  ),
                  IconButton(
                    iconSize: 30,
                    icon: const Icon(Icons.image, color: Colors.green),
                    onPressed: _pickAndSendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: (_) {
                        socket?.emit("typing", {"roomId": widget.orderId});
                      },
                      decoration: InputDecoration(
                        hintText: "اكتب رسالة...",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: Colors.green,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _send,
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
