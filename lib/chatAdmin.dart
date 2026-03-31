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

late IO.Socket socket;

void initSocket() {
  socket = IO.io(
    'https://eshtreeli-backend-2026-1.onrender.com',
    IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build(),
  );
}

// ================= MODEL =================
class ChatMessage {
  final String senderId;
  final String message;
  final DateTime time;
  final String type;
  final String? audioUrl;

  ChatMessage({
    required this.senderId,
    required this.message,
    required this.time,
    this.type = "text",
    this.audioUrl,
  });
}

// ================= PAGE =================
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final AudioRecorder _record = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool isTyping = false;
  bool isRecording = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  String? _currentlyPlayingUrl;

  List<ChatMessage> messages = [];

  String? myId;
  String? adminId;
  String adminName = "الدعم الفني";
  bool joinedRoom = false;

  @override
  void initState() {
    super.initState();

    initSocket();

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

    socket.onConnect((_) async {
      await _init();
      _joinRoom();
      await _loadOldMessages();
      _setupSocket();
    });

    socket.connect();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    myId = prefs.getString('id');

    final res = await http.get(Uri.parse(
        "https://eshtreeli-backend-2026-1.onrender.com/api/users/last-admin"));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      adminId = data['admin']['_id'];
      adminName = data['admin']['name'];
    }

    setState(() {});
  }

  void _joinRoom() {
    if (myId == null || adminId == null || joinedRoom) return;
    final roomId = ([myId!, adminId!]..sort()).join("_");
    socket.emit("joinRoom", {"roomId": roomId});
    joinedRoom = true;
  }

  Future<void> _loadOldMessages() async {
    final roomId = ([myId!, adminId!]..sort()).join("_");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final res = await http.get(
      Uri.parse(
          "https://eshtreeli-backend-2026-1.onrender.com/api/chat/$roomId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List list = data['messages'];

      setState(() {
        messages = list.map((m) {
          return ChatMessage(
            senderId:
                m['senderId'] is Map ? m['senderId']['_id'] : m['senderId'],
            message: m['message'] ?? "",
            type: m['type'] ?? "text",
            audioUrl: m['audioUrl'],
            time: DateTime.parse(m['createdAt']),
          );
        }).toList();
      });

      _scrollToBottom();
    }
  }

  void _setupSocket() {
    socket.on("typing", (_) {
      setState(() => isTyping = true);
    });

    socket.on("stopTyping", (_) {
      setState(() => isTyping = false);
    });

    socket.on('receiveMessage', (data) {
      setState(() {
        messages.add(ChatMessage(
          senderId: data['senderId'],
          message: data['message'] ?? "",
          type: data['type'] ?? "text",
          audioUrl: data['audioUrl'],
          time: DateTime.now(),
        ));
      });

      _scrollToBottom();
    });
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty || myId == null || adminId == null) return;

    final roomId = ([myId!, adminId!]..sort()).join("_");
    socket.emit("stopTyping", {"roomId": roomId});

    socket.emit('sendMessage', {
      'roomId': roomId,
      'senderId': myId!,
      'receiverId': adminId!,
      'message': text,
    });

    _controller.clear();
  }

  Future<void> _startRecording() async {
    if (!await _record.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
    if (path == null || myId == null || adminId == null) return;

    final roomId = ([myId!, adminId!]..sort()).join("_");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    var request = http.MultipartRequest(
      "POST",
      Uri.parse(
          "https://eshtreeli-backend-2026-1.onrender.com/api/chat/upload-audio"),
    );

    request.headers['Authorization'] = "Bearer $token";
    request.fields['roomId'] = roomId;
    request.fields['receiverId'] = adminId!;

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
      final file = File('${dir.path}/temp_audio_file.m4a');
      await file.writeAsBytes(response.bodyBytes);

      _currentlyPlayingUrl = fullUrl;
      _position = Duration.zero;

      await _player.play(DeviceFileSource(file.path));
    } catch (e) {}
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  @override
  void dispose() {
    socket.disconnect();
    socket.clearListeners();
    _controller.dispose();
    _scrollController.dispose();
    _player.dispose();
    _record.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: Text(adminName), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg.senderId == myId;

                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color.fromARGB(255, 96, 126, 57)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 3)
                          ],
                        ),
                        child: msg.type == "audio" && msg.audioUrl != null
                            ? Builder(
                                builder: (context) {
                                  final fullUrl =
                                      "https://eshtreeli-backend-2026-1.onrender.com${msg.audioUrl}";
                                  final isCurrent =
                                      _currentlyPlayingUrl == fullUrl;

                                  return Row(
                                    children: [
                                      IconButton(
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
                                          _playAudio(msg.audioUrl!);
                                        },
                                      ),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Directionality(
                                              textDirection: TextDirection.ltr,
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
                                            Text(
                                              isCurrent
                                                  ? _formatDuration(_position)
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
                                      ),
                                    ],
                                  );
                                },
                              )
                            : Text(
                                msg.message,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _formatTime(msg.time),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isRecording ? Icons.stop : Icons.mic,
                    color: isRecording ? Colors.red : Colors.black,
                  ),
                  onPressed: isRecording ? _stopRecording : _startRecording,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: sendMessage,
                    decoration: InputDecoration(
                      hintText: "اكتب رسالة...",
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                CircleAvatar(
                  backgroundColor: const Color.fromARGB(255, 255, 174, 0),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => sendMessage(_controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
