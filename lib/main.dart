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
      home: const MainListenerScreen(), // ✅ 메인 대기 화면
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
    // TODO: 실제 서버 주소로 변경
    channel = WebSocketChannel.connect(Uri.parse('wss://example.com/sound'));

    // 서버 메시지 수신
    channel.stream.listen((message) {
      setState(() => lastMessage = message);

      final data = jsonDecode(message);
      final type = data["type"];

      if (type == "voice") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VoiceScreen(text: data["content"]),
          ),
        );
      } else if (type == "car") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CarSoundScreen(
              sound: data["content"],
              direction: data["direction"],
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF64B5F6)], // 파란색 그라데이션
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 상단 아이콘
              const Icon(Icons.hearing, size: 100, color: Colors.white),
              const SizedBox(height: 30),

              // 메인 텍스트
              const Text(
                "소리 감지 대기 중...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              // 서브 텍스트 (실시간 서버 연결 표시)
              Text(
                lastMessage,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // 로딩 애니메이션
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

// ✅ 사람 말소리 화면
class VoiceScreen extends StatelessWidget {
  final String text;
  const VoiceScreen({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("사람 음성")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.record_voice_over, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              text,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("홈으로"),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ 차 소리(경적/사이렌) 화면
class CarSoundScreen extends StatelessWidget {
  final String sound;
  final String direction;
  const CarSoundScreen({
    super.key,
    required this.sound,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("차량 소리 감지")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              "$sound 감지!",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("방향: $direction", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("홈으로"),
            ),
          ],
        ),
      ),
    );
  }
}
