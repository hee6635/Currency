import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vn_currency/core/money.dart';
import 'package:vn_currency/core/voice_rules.dart';

/// 저장소의 voice_rules.json 이 깨지지 않았고, 넣은 보정이 의도대로 동작하는지
void main() {
  final rules = VoiceRules.parse(File('voice_rules.json').readAsStringSync());

  setUp(() => spokenExtraFixes = rules!.fixes);
  tearDown(() => spokenExtraFixes = []);

  test('규칙 파일을 읽을 수 있고 버전이 있음', () {
    expect(rules, isNotNull);
    expect(rules!.version, greaterThan(0));
  });

  test('K(천) 단위 보정', () {
    String say(String t) => applySpoken('', t, addMode: true).expr;
    expect(say('OK'), '5000');
    expect(say('오케이'), '5000');
    expect(say('오십 케이'), '50000');
    expect(say('이십오 케이'), '25000');
    expect(say('백오십 케이'), '150000');
    expect(say('오만'), '50000'); // 다른 말은 그대로
    expect(say('이십칠만 동'), '270000');
  });

  test('v3: 음성 기록 55개 반영', () {
    String say(String t) => applySpoken('', t, addMode: true).expr;
    expect(say('3탄'), '3000');
    expect(say('우만동'), '50000');
    expect(say('젤만'), '70000');
    expect(say('57,000 /'), '57000');
  });

  test('v4: 만 동이 동네 이름으로 들림', () {
    String say(String t) => applySpoken('', t, addMode: true).expr;
    expect(say('운동'), '50000');
    expect(say('오금동'), '50000');
    expect(say('이문동'), '20000');
    expect(say('이현동'), '20000');
    expect(say('45 운동'), '450000');
    expect(say('45분도'), '450000');
    expect(say('45분 동'), '450000');
    expect(say('80년도'), '800000');
    expect(say('80년대'), '800000');
    expect(say('칠성동'), '7000');
    expect(say('이십칠만 동'), '270000'); // 원래 말은 그대로
    expect(say('오만 동'), '50000');
    expect(say('삼천 동'), '3000');
  });
}
