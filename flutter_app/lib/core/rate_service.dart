import 'dart:convert';

import 'package:http/http.dart' as http;

/// 환율 정보: 1원이 몇 동인지 + 기준 시각
class RateInfo {
  const RateInfo(this.vndPerKrw, this.updatedAt);
  final double vndPerKrw;
  final DateTime updatedAt;
}

class RateException implements Exception {
  const RateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// ExchangeRate-API 무료 공개 주소 (하루 1번 갱신, 키 불필요).
/// 원화 기준으로 받으면 VND 값이 곧 "1원 = ?동".
class RateService {
  RateService({http.Client? client}) : _client = client ?? http.Client();

  static final _url = Uri.parse('https://open.er-api.com/v6/latest/KRW');
  final http.Client _client;

  Future<RateInfo> fetch() async {
    final http.Response res;
    try {
      res = await _client.get(_url).timeout(const Duration(seconds: 8));
    } catch (_) {
      throw const RateException('인터넷 연결을 확인해 주세요');
    }
    if (res.statusCode != 200) {
      throw RateException('서버 응답 오류 (${res.statusCode})');
    }
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['result'] != 'success') throw const FormatException();
      final vnd = (data['rates'] as Map<String, dynamic>)['VND'] as num;
      final unix = data['time_last_update_unix'] as num;
      if (vnd <= 0) throw const FormatException();
      return RateInfo(
        vnd.toDouble(),
        DateTime.fromMillisecondsSinceEpoch(unix.toInt() * 1000),
      );
    } catch (_) {
      throw const RateException('환율 데이터를 읽을 수 없어요');
    }
  }
}
