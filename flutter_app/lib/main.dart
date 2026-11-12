import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'ui/convert_page.dart';
import 'ui/other_pages.dart';
import 'ui/theme.dart';
import 'ui/voice_popup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  // 홈 화면 위젯·측면 버튼으로 연 음성 창
  if (PlatformDispatcher.instance.defaultRouteName == '/voice') {
    state.load().then((_) => state.openVoice());
    runApp(VoicePopupApp(state: state));
    return;
  }
  state.load().then((_) => state.syncFromPopup());
  runApp(VnCurrencyApp(state: state));
}

class VnCurrencyApp extends StatelessWidget {
  const VnCurrencyApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: '베트남 환율',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    // 앱이 백그라운드로 갈 때 메모를 바로 저장하고, 하던 계산은 최근 계산에 넣어 둔다
    // (다시 켜면 입력창은 비어 있고, 최근 계산에서 불러오면 이어서 할 수 있다)
    _life = AppLifecycleListener(
      // 음성 팝업에서 "앱으로 이동"했거나 팝업에서 계산했으면 이어받는다
      onResume: () => AppScope.read(context).syncFromPopup(),
      onHide: () {
        final s = AppScope.read(context);
        s.saveMemoNow();
        if (s.loaded) s.archiveExpr();
      },
    );
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: const [
            ConvertPage(),
            TablePage(),
            NotesPage(),
            PhrasesPage(),
            MemoPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          FocusScope.of(context).unfocus();
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate_rounded),
            label: '환산',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_rows_outlined),
            selectedIcon: Icon(Icons.table_rows_rounded),
            label: '환산표',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: '지폐',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: '보여주기',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2_rounded),
            label: '메모',
          ),
        ],
      ),
    );
  }
}
