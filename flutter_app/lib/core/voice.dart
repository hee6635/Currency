import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 폰에 들어 있는 음성인식(구글/삼성)을 한국어로 쓰는 얇은 포장.
class VoiceInput {
  final _stt = SpeechToText();
  bool _ready = false;
  String? _localeId;

  /// 폰 음성인식 목록에 한국어가 없음 (구글 앱의 한국어 음성 데이터 필요)
  bool noKorean = false;
  void Function()? _onDone;
  void Function()? _onReady;
  void Function(String)? _onError;

  bool get isListening => _stt.isListening;

  /// 듣기 시작. 시작하지 못하면 이유(한국어 문장)를 돌려준다.
  Future<String?> start({
    required void Function(String text, bool isFinal) onText,
    required void Function() onDone,
    required void Function(String message) onError,
    void Function()? onReady,
  }) async {
    _onDone = onDone;
    _onReady = onReady;
    _onError = onError;
    if (!_ready) {
      try {
        _ready = await _stt.initialize(onStatus: _status, onError: _error);
      } catch (_) {
        _ready = false;
      }
      if (!_ready) return '이 폰에서 음성인식을 쓸 수 없거나 마이크 권한이 없어요';
      // 폰에 있는 한국어 음성인식 이름 찾기 (ko_KR, ko-KR 등 폰마다 다름)
      try {
        final locales = await _stt.locales();
        final ko = locales.where(
          (l) => l.localeId.toLowerCase().startsWith('ko'),
        );
        _localeId = ko.isEmpty ? null : ko.first.localeId;
        if (ko.isEmpty && locales.isNotEmpty) noKorean = true;
      } catch (_) {
        _localeId = 'ko_KR';
      }
    }
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: _localeId ?? 'ko_KR',
        // 무전기 방식: 버튼을 떼면 멈추므로 넉넉하게
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 30),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (SpeechRecognitionResult r) =>
          onText(r.recognizedWords, r.finalResult),
    );
    return null;
  }

  Future<void> stop() => _stt.stop();

  void _status(String status) {
    if (status == SpeechToText.listeningStatus) _onReady?.call();
    // 'notListening'은 손을 떼서 멈춘 순간에도 오고, 최종 결과는 그 뒤에 온다.
    // 끝은 최종 결과까지 전달된 뒤의 'done'으로만 판단한다.
    if (status == SpeechToText.doneStatus) _onDone?.call();
  }

  void _error(SpeechRecognitionError e) {
    final msg = switch (e.errorMsg) {
      'error_no_match' || 'error_speech_timeout' => '잘 안 들렸어요. 다시 말해 주세요',
      'error_network' || 'error_network_timeout' => '인터넷 연결이 필요해요',
      'error_permission' ||
      'error_insufficient_permissions' => '마이크 권한을 허용해 주세요',
      'error_client' || 'error_recognizer_busy' => '음성인식이 바빠요. 잠시 후 다시 눌러 주세요',
      'error_language_not_supported' || 'error_language_unavailable' =>
        '한국어 음성인식이 없어요. 구글 앱의 음성 설정에서 한국어를 받아 주세요',
      _ => '음성인식 오류 (${e.errorMsg})',
    };
    _onError?.call(msg);
    _onDone?.call();
  }
}
