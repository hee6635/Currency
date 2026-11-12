import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/platform_bridge.dart';
import '../state/app_state.dart';
import 'convert_page.dart';
import 'theme.dart';

/// 홈 화면 위젯·측면 버튼·아이콘 길게 누르기로 여는 음성 입력 창.
/// 홈 화면 위에 앱 안의 음성 창과 같은 모양으로 뜬다.
class VoicePopupApp extends StatelessWidget {
  const VoicePopupApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    ThemeData clear(Brightness b) =>
        buildTheme(b).copyWith(scaffoldBackgroundColor: Colors.transparent);
    return AppScope(
      state: state,
      child: MaterialApp(
        title: '말로 입력',
        debugShowCheckedModeBanner: false,
        theme: clear(Brightness.light),
        darkTheme: clear(Brightness.dark),
        color: Colors.transparent,
        home: const _PopupPage(),
      ),
    );
  }
}

class _PopupPage extends StatelessWidget {
  const _PopupPage();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Future<void> close() async {
      s.closeVoice();
      s.archiveExpr(); // 하던 식은 최근 계산에
      await PlatformBridge.closePopup();
      await SystemNavigator.pop();
    }

    Future<void> openApp() async {
      s.closeVoice();
      s.archiveExpr();
      await s.handOffToApp(); // 앱이 이 식을 이어받는다
      await PlatformBridge.openMainApp();
      await PlatformBridge.closePopup();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Scaffold(
        body: VoicePanel(onClose: close, onOpenApp: openApp),
      ),
    );
  }
}
