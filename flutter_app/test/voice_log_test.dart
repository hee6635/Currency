import 'package:flutter_test/flutter_test.dart';
import 'package:vn_currency/core/voice_log.dart';

void main() {
  VoiceLogEntry entry({String result = '+ 2,000', List<String>? heard}) =>
      VoiceLogEntry(
        at: DateTime(2026, 11, 7, 14, 3, 12),
        currency: '동',
        heard: heard ?? ['이촌 동', '이천동'],
        chosen: '이촌 동',
        result: result,
        problem: result.isEmpty ? '아무 말도 못 들었어요' : null,
        events: ['누름 0.0', '준비 0.4', '뗌 2.1', '끝 2.6'],
      );

  test('저장했다 다시 읽어도 같음', () {
    final e = entry()..wrong = true;
    final back = VoiceLogEntry.fromJson(e.toJson());
    expect(back.heard, e.heard);
    expect(back.result, e.result);
    expect(back.events, e.events);
    expect(back.wrong, isTrue);
    expect(back.at, e.at);
  });

  test('보내기 좋은 글자: 성공/실패 모두', () {
    final ok = entry().toText();
    expect(ok, contains('들림: "이촌 동"'));
    expect(ok, contains('후보: "이천동"'));
    expect(ok, contains('→ + 2,000'));
    final fail = entry(result: '', heard: const []).toText();
    expect(fail, contains('(아무것도 못 들음)'));
    expect(fail, contains('✗ 아무 말도 못 들었어요'));
  });

  test('틀린·실패한 것만 내보내기', () async {
    final log = VoiceLog();
    await log.add(entry());
    await log.add(entry(result: ''));
    expect(log.export(wrongOnly: true), contains('기록 1개'));
    expect(log.export(), contains('기록 2개'));
  });
}
