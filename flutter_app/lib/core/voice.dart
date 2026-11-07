import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 폰에 들어 있는 음성인식(구글/삼성)을 한국어로 쓰는 얇은 포장.
class VoiceInput {
  final _stt = SpeechToText();
  bool _ready = false;
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
    }
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'ko_KR',
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
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      _onDone?.call();
    }
  }

  void _error(SpeechRecognitionError e) {
    final msg = switch (e.errorMsg) {
      'error_no_match' || 'error_speech_timeout' => '잘 안 들렸어요. 다시 말해 주세요',
      'error_network' || 'error_network_timeout' => '인터넷 연결이 필요해요',
      'error_permission' ||
      'error_insufficient_permissions' => '마이크 권한을 허용해 주세요',
      _ => '음성인식 오류 (${e.errorMsg})',
    };
    _onError?.call(msg);
    _onDone?.call();
  }
}
