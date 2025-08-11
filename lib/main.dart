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

class SoundEvent {
  final String label;
  final int direction;
  final double confidence;
  final double energy;
  final int ms;
  final DateTime time;
  SoundEvent({
    required this.label,
    required this.direction,
    required this.confidence,
    required this.energy,
    required this.ms,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class _MainListenerScreenState extends State<MainListenerScreen> {
  // ===== 모델/상태 =====

  late WebSocketChannel channel;
  late StreamSubscription sub;

  String lastMessage = "서버 연결 대기 중...";
  final List<SoundEvent> _events = [];
  SoundEvent? _latest;

  @override
  void initState() {
    super.initState();

    dev.log('WS connecting...');
    print('WS connecting...');

    channel = WebSocketChannel.connect(
      Uri.parse('ws://3.24.208.26:8000/ws/esp32?esp_id=mobile-01'),
    );

    sub = channel.stream.listen(
      (message) {
        // 원본 메시지 무조건 출력
        print('WS RAW: $message');

        setState(() => lastMessage = message);

        try {
          final data = jsonDecode(message) as Map<String, dynamic>;

          // 1) UI 표시용 파싱/적재
          if (data['event'] == 'info') {
            final ev = SoundEvent(
              label: (data['label'] ?? '').toString(),
              direction: (data['direction'] ?? -1) is num
                  ? (data['direction'] as num).toInt()
                  : int.tryParse((data['direction'] ?? '-1').toString()) ?? -1,
              confidence: (data['confidence'] ?? 0) is num
                  ? (data['confidence'] as num).toDouble()
                  : double.tryParse((data['confidence'] ?? '0').toString()) ??
                        0.0,
              energy: (data['energy'] ?? 0) is num
                  ? (data['energy'] as num).toDouble()
                  : double.tryParse((data['energy'] ?? '0').toString()) ?? 0.0,
              ms: (data['ms'] ?? 0) is num
                  ? (data['ms'] as num).toInt()
                  : int.tryParse((data['ms'] ?? '0').toString()) ?? 0,
            );

            // (옵션) 너무 낮은 신뢰도 거르기
            if (ev.confidence >= 0.12) {
              _latest = ev;
              _events.insert(0, ev);
              if (_events.length > 100) _events.removeLast();
            }
          }

          // 2) 기존 알림/네비 트리거 유지
          _handlePush(data);
        } catch (e, st) {
          dev.log('WS non-JSON message', error: e, stackTrace: st);
          print('WS non-JSON message: $e');
        }
      },
      onError: (e, st) {
        dev.log('WS error', error: e, stackTrace: st);
        print('WS error: $e');
        setState(() => lastMessage = '연결 오류: $e');
      },
      onDone: () {
        dev.log(
          'WS closed. code=${channel.closeCode} reason=${channel.closeReason}',
        );
        print('WS closed');
        if (mounted) {
          setState(() => lastMessage = '서버가 연결을 종료했습니다.');
        }
      },
      cancelOnError: true,
    );

    // 5초 동안 아무 이벤트 없으면 힌트
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (lastMessage == '서버 연결 대기 중...') {
        dev.log('WS no event within 5s (timeout hint)');
        print('WS no event within 5s (timeout hint)');
        setState(() => lastMessage = '연결 대기 중(5초 경과) — 서버/포트/보안그룹 확인');
      }
    });
  }

  // ===== 라벨별 아이콘 =====
  IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('vehicle') || l.contains('car')) {
      return Icons.directions_car;
    }
    if (l.contains('siren')) return Icons.emergency;
    if (l.contains('horn') || l.contains('buzz')) {
      return Icons.notifications_active;
    }
    if (l.contains('speech') || l.contains('voice')) {
      return Icons.record_voice_over;
    }
    if (l.contains('frog')) return Icons.grass;
    return Icons.hearing;
  }

  // ===== 기존 푸시 핸들러 (팝업/네비) =====
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
    try {
      sub.cancel();
    } catch (_) {}
    try {
      channel.sink.close();
    } catch (_) {}
    super.dispose();
  }

  // ===== UI =====
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
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hearing, size: 80, color: Colors.white),
              const SizedBox(height: 12),
              const Text(
                "소리 감지 대기 중...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 최근 이벤트 카드
              if (_latest != null)
                Container(
                  width: 360,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _iconFor(_latest!.label),
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _latest!.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "방향: ${_latest!.direction}°   신뢰도: ${_latest!.confidence.toStringAsFixed(3)}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              "에너지: ${_latest!.energy.toStringAsFixed(1)}   윈도우(ms): ${_latest!.ms}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "${_latest!.time.toLocal()}",
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text("아직 수신 없음", style: TextStyle(color: Colors.white54)),

              const SizedBox(height: 18),

              // 로그 리스트
              SizedBox(
                height: 280,
                width: 360,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _events.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12, height: 12),
                    itemBuilder: (context, i) {
                      final e = _events[i];
                      return Row(
                        children: [
                          Icon(
                            _iconFor(e.label),
                            color: Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${e.label}  (${e.direction}°)",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            e.confidence.toStringAsFixed(3),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),
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
