import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

/// 앱 시작 위젯
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wearable Sound Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MainListenerScreen(),
    );
  }
}

/// 수신 이벤트 모델
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

/// 메인 화면(실시간 갱신)
class MainListenerScreen extends StatefulWidget {
  const MainListenerScreen({super.key});
  @override
  State<MainListenerScreen> createState() => _MainListenerScreenState();
}

class _MainListenerScreenState extends State<MainListenerScreen> {
  late WebSocketChannel channel;
  StreamSubscription? sub;

  String statusText = '서버 연결 대기 중...';
  final List<SoundEvent> _events = [];
  SoundEvent? _latest;

  Timer? _silenceTimer;
  static const Duration _silenceTimeout = Duration(seconds: 3);
  String? _lastEventKey;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  // ===== 한글 라벨 매핑(원문 그대로 쓰고 싶으면 korLabel() 대신 label 그대로 표시) =====
  String korLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('speech')) return '사람 목소리';
    if (l.contains('car') || l.contains('vehicle')) return '차량 소리';
    if (l.contains('siren')) return '사이렌';
    if (l.contains('horn')) return '경적';
    if (l.contains('buzz')) return '윙~ (Buzz)';
    if (l.contains('electric shaver')) return '전기 면도기';
    if (l.contains('sheep')) return '양 울음';
    return label;
  }

  IconData iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('vehicle') || l.contains('car')) return Icons.directions_car;
    if (l.contains('siren')) return Icons.emergency;
    if (l.contains('horn') || l.contains('buzz'))
      return Icons.notifications_active;
    if (l.contains('speech') || l.contains('voice'))
      return Icons.record_voice_over;
    if (l.contains('sheep') || l.contains('frog')) return Icons.pets;
    return Icons.hearing;
  }

  void _connectWebSocket() {
    dev.log('WS connecting...');
    channel = WebSocketChannel.connect(
      Uri.parse('ws://3.24.208.26:8000/ws/esp32?esp_id=mobile-01'),
    );

    sub = channel.stream.listen(
      (message) {
        // 원본 로그
        print('WS RAW: $message');

        try {
          final data = jsonDecode(message) as Map<String, dynamic>;
          _handlePush(data); // 메시지 핸들
        } catch (e, st) {
          dev.log('WS non-JSON', error: e, stackTrace: st);
        }
      },

      onError: (e, st) {
        dev.log('WS error', error: e, stackTrace: st);
        if (!mounted) return;
        _silenceTimer?.cancel();
        setState(() {
          _latest = null;
          statusText = '연결 오류: $e';
        });
      },

      onDone: () {
        dev.log(
          'WS closed. code=${channel.closeCode} reason=${channel.closeReason}',
        );
        if (!mounted) return;
        _silenceTimer?.cancel();
        setState(() {
          _latest = null;
          statusText = '연결 종료됨';
        });
      },
      cancelOnError: true,
    );

    // 연결 힌트
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (statusText == '서버 연결 대기 중...') {
        setState(() => statusText = '연결 대기 중 — 서버/포트 확인 필요');
      }
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    channel.sink.close();
    _silenceTimer?.cancel(); // 무신호 타이머 해제
    super.dispose();
  }

  void _armSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, () {
      if (!mounted) return;
      setState(() {
        _latest = null;
        // _events.clear(); // 무신호 시 로그도 비우고 싶다면 주석 해제
        statusText = '최근 수신 없음';
      });
    });
  }

  void _handlePush(Map<String, dynamic> data) {
    if (data['event'] != 'info') return;

    final labelStr = (data['label'] ?? '').toString();

    // 🚫 silence일 경우 아예 무시
    if (labelStr.toLowerCase().contains('silence')) {
      return; // 화면/로그에 아무것도 안 남김
    }

    final ev = SoundEvent(
      label: (data['label'] ?? '').toString(),
      direction: (data['direction'] ?? -1) is num
          ? (data['direction'] as num).toInt()
          : int.tryParse((data['direction'] ?? '-1').toString()) ?? -1,
      confidence: (data['confidence'] ?? 0) is num
          ? (data['confidence'] as num).toDouble()
          : double.tryParse((data['confidence'] ?? '0').toString()) ?? 0.0,
      energy: (data['energy'] ?? 0) is num
          ? (data['energy'] as num).toDouble()
          : double.tryParse((data['energy'] ?? '0').toString()) ?? 0.0,
      ms: (data['ms'] ?? 0) is num
          ? (data['ms'] as num).toInt()
          : int.tryParse((data['ms'] ?? '0').toString()) ?? 0,
    );

    if (ev.confidence < 0.12) {
      // 낮은 신뢰도일 때도 "무신호" 취급하려면 타이머만 재설정하지 말고 return
      return;
    }

    final key =
        '${ev.label}|${ev.direction}|${ev.confidence.toStringAsFixed(3)}|${ev.energy.toStringAsFixed(1)}|${ev.ms}';
    final isDuplicate = key == _lastEventKey;

    if (!mounted) return;
    setState(() {
      _latest = ev;
      if (!isDuplicate) {
        _events.insert(0, ev);
        if (_events.length > 100) _events.removeLast();
      }
      _lastEventKey = key;
      statusText = '수신 중';
    });

    // ▼ 새 데이터 수신했으므로 무신호 타이머 재설정
    _armSilenceTimer();
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1f3b73),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(Icons.hearing, size: 96, color: Colors.white70),
                const SizedBox(height: 16),
                const Text(
                  '소리 감지 중...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(statusText, style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 24),

                // === 현재 감지 카드 ===
                if (_latest != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          iconFor(_latest!.label),
                          color: Colors.white,
                          size: 36,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                korLabel(_latest!.label),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                children: [
                                  _chipText('방향: ${_latest!.direction}°'),
                                  _chipText(
                                    '신뢰도: ${_latest!.confidence.toStringAsFixed(3)}',
                                  ),
                                  _chipText(
                                    '에너지: ${_latest!.energy.toStringAsFixed(1)}',
                                  ),
                                  _chipText('윈도우(ms): ${_latest!.ms}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _latest!.time.toLocal().toString(),
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
                  const Text(
                    '아직 수신 없음',
                    style: TextStyle(color: Colors.white54),
                  ),
                const SizedBox(height: 24),

                // === 로그 리스트 ===
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 420),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _events.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              '최근 이벤트가 없습니다.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _events.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final e = _events[i];
                            final isLatestRow = i == 0; // 맨 위(최신) 줄만 강조

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: (isLatestRow
                                    ? const Color.fromARGB(
                                        255,
                                        113,
                                        148,
                                        255,
                                      ).withOpacity(0.4) // 강조 배경
                                    : Colors.white.withOpacity(0.06)), // 기존 배경톤
                                borderRadius: BorderRadius.circular(12),
                                border: isLatestRow
                                    ? Border.all(
                                        color: Color.fromARGB(
                                          255,
                                          144,
                                          172,
                                          255,
                                        ),
                                        width: 1,
                                      ) // 강조 테두리
                                    : null,
                                boxShadow: isLatestRow
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    iconFor(e.label),
                                    color: isLatestRow
                                        ? Colors.white
                                        : Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${korLabel(e.label)}  (${e.direction}°)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: isLatestRow
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    e.confidence.toStringAsFixed(3),
                                    style: TextStyle(
                                      color: isLatestRow
                                          ? Colors.white
                                          : Colors.white70,
                                      fontFamily: 'monospace',
                                      fontWeight: isLatestRow
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipText(String s) =>
      Text(s, style: const TextStyle(color: Colors.white70, fontSize: 14));
}
