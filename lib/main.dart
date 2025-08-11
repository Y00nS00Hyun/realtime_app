import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
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

class MainListenerScreen extends StatefulWidget {
  const MainListenerScreen({super.key});

  @override
  State<MainListenerScreen> createState() => _MainListenerScreenState();
}

class _MainListenerScreenState extends State<MainListenerScreen> {
  late WebSocketChannel channel;
  late StreamSubscription sub;
  String lastMessage = "서버 연결 대기 중...";

  @override
  void initState() {
    super.initState();

    dev.log('WS connecting...'); // ← 로그
    print('WS connecting...'); // ← 브라우저 콘솔용

    channel = WebSocketChannel.connect(
      Uri.parse('ws://3.24.208.26:8000/ws/esp32?esp_id=mobile-01'),
    );

    sub = channel.stream.listen(
      (message) {
        dev.log('WS message: $message'); // ← 수신 로그
        print('WS message: $message');

        setState(() => lastMessage = message);
        try {
          final data = jsonDecode(message) as Map<String, dynamic>;
          _handlePush(data);
        } catch (e, st) {
          dev.log('WS non-JSON message', error: e, stackTrace: st);
          print('WS non-JSON message: $e');
        }
      },
      onError: (e, st) {
        dev.log('WS error', error: e, stackTrace: st); // ← 에러 로그
        print('WS error: $e');
        setState(() => lastMessage = '연결 오류: $e');
      },
      onDone: () {
        dev.log(
          'WS closed. code=${channel.closeCode} reason=${channel.closeReason}',
        ); // ← 종료 로그
        print('WS closed');
        if (mounted) {
          setState(() => lastMessage = '서버가 연결을 종료했습니다.');
        }
      },
      cancelOnError: true,
    );

    // 5초 동안 아무 이벤트 없을 때 힌트
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (lastMessage == '서버 연결 대기 중...') {
        dev.log('WS no event within 5s (timeout hint)');
        print('WS no event within 5s (timeout hint)');
        setState(() => lastMessage = '연결 대기 중(5초 경과) — 서버/포트/보안그룹 확인');
      }
    });
  }

  // 👇 initState 바깥(같은 클래스 안)
  void _handlePush(Map<String, dynamic> data) {
    if (data['event'] != 'info') return;

    final label = (data['label'] ?? '').toString();
    final direction = (data['direction'] ?? -1).toString();

    if (!mounted) return;

    final l = label.toLowerCase();
    if (l.contains('speech')) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const VoiceScreen(text: '음성 감지'),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } else if (l.contains('car') || l.contains('horn') || l.contains('siren')) {
      _showCarDialog(context, label, direction);
    }
  }

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
                  sound,
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
    sub.cancel();
    channel.sink.close(); // 연결 종료
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
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
                  color: Colors.white.withValues(alpha: 0.1),
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

class VoiceScreen extends StatelessWidget {
  final String text;
  const VoiceScreen({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
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
