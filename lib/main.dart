import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wearable Sound Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const MainListenerScreen(),
    );
  }
}

// ✅ 메인 화면: 서버에서 소리 종류 수신 → 자동 화면 전환
class MainListenerScreen extends StatefulWidget {
  const MainListenerScreen({super.key});

  @override
  State<MainListenerScreen> createState() => _MainListenerScreenState();
}

class _MainListenerScreenState extends State<MainListenerScreen> {
  late WebSocketChannel channel;
  String lastMessage = "서버 연결 대기 중...";

  @override
  void initState() {
    super.initState();

    // 🔹 실제 서버 연결 (필요 시 활성화)
    // channel = WebSocketChannel.connect(Uri.parse('wss://example.com/sound'));
    // channel.stream.listen((message) {
    //   setState(() => lastMessage = message);
    //   final data = jsonDecode(message);
    //   _handleMessage(data);
    // });

    // ✅ 테스트용: 3초 후 음성 메시지
    Future.delayed(const Duration(seconds: 3), () {
      final fakeVoiceMessage = {
        "type": "voice",
        "content": "안녕하세요! 테스트 음성입니다.",
      };
      _handleMessage(fakeVoiceMessage);
    });

    // ✅ 테스트용: 6초 후 차량 경적 메시지
    Future.delayed(const Duration(seconds: 6), () {
      final fakeCarMessage = {
        "type": "car",
        "content": "경적 소리",
        "direction": "왼쪽",
      };
      _handleMessage(fakeCarMessage);
    });
  }

  // ✅ 메시지 처리 후 화면 전환 or 팝업 띄우기
  void _handleMessage(Map<String, dynamic> data) {
    final type = data["type"];

    if (type == "voice") {
      // 음성 메시지는 새 화면으로 전환
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => VoiceScreen(text: data["content"]),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } else if (type == "car") {
      // 차량 소리는 팝업으로 띄움
      _showCarDialog(context, data["content"], data["direction"]);
    }
  }

  // ✅ 차량 소리 팝업 다이얼로그 (문구 간결)
  void _showCarDialog(BuildContext context, String sound, String direction) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.redAccent, Colors.deepOrangeAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_car, size: 60, color: Colors.white),
                const SizedBox(height: 15),
                Text(
                  sound, // ex: 경적 소리 / 사이렌 소리
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "방향: $direction",
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text("닫기"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // channel.sink.close(); // 실제 서버 연결 시 닫기
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)], // 예쁜 블루 그라데이션
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hearing, size: 110, color: Colors.white),
              const SizedBox(height: 30),
              const Text(
                "소리 감지 대기 중...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  lastMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ 음성 화면 (그라데이션 배경 + 큰 텍스트만)
class VoiceScreen extends StatelessWidget {
  final String text;
  const VoiceScreen({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)], // 시원한 블루톤 그라데이션
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.record_voice_over,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 30),
              const Text(
                "음성 감지됨",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
