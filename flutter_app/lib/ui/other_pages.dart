import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import 'banknote.dart';
import 'common.dart';
import 'theme.dart';

// ───────────────────────── 환산표 ─────────────────────────

class TablePage extends StatelessWidget {
  const TablePage({super.key});

  static const _vnd = [10000, 20000, 50000, 100000, 200000, 500000, 1000000, 2000000];
  static const _krw = [1000, 5000, 10000, 30000, 50000, 100000, 300000, 500000];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.palette;
    final src = s.tableFrom;
    final amounts = src == Currency.vnd ? _vnd : _krw;
    final dst = src.other;

    num conv(int a) {
      final v = s.convert(a, src);
      return dst == Currency.krw ? roundTo(v, 10) : roundTo(v, 100);
    }

    return Column(
      children: [
        const PageHeader(title: '빠른 환산표'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<Currency>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Currency.vnd, label: Text('동 → 원')),
                ButtonSegment(value: Currency.krw, label: Text('원 → 동')),
              ],
              selected: {src},
              onSelectionChanged: (v) => s.setTableFrom(v.first),
            ),
          ),
        ),
        Expanded(
          child: s.rate == null
              ? Center(child: Text('환율이 있어야 표를 만들 수 있어요', style: TextStyle(color: p.muted)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      child: Column(
                        children: [
                          for (final (i, a) in amounts.indexed) ...[
                            if (i > 0) Divider(height: 1, color: p.line),
                            _TableRow(
                              left: '${fmt(a)}${src.unit}',
                              leftSub: koreanUnit(a).isEmpty ? '' : '${koreanUnit(a)}${src.unit}',
                              right: '${fmt(conv(a))}${dst.unit}',
                              rightSub: koreanUnit(conv(a)).isEmpty ? '' : '${koreanUnit(conv(a))}${dst.unit}',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('표 복사하기'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final lines = [
                            '[1원 = ${s.rate!.toStringAsFixed(2)}동 기준]',
                            for (final a in amounts) '${fmt(a)}${src.unit} = ${fmt(conv(a))}${dst.unit}',
                          ];
                          Clipboard.setData(ClipboardData(text: lines.join('\n')));
                          toast(context, '환산표를 복사했어요');
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.left, required this.leftSub, required this.right, required this.rightSub});
  final String left, leftSub, right, rightSub;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    TextStyle big(Color c) => TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c, fontFeatures: tabular);
    final small = TextStyle(fontSize: 12, color: p.muted, fontFeatures: tabular);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(left, style: big(p.ink)),
                if (leftSub.isNotEmpty) Text(leftSub, style: small),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, size: 16, color: p.muted),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(right, style: big(Theme.of(context).brightness == Brightness.light ? p.navyHi : p.gold)),
                if (rightSub.isNotEmpty) Text(rightSub, style: small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 지폐 세기 ─────────────────────────

class _Note {
  const _Note(this.value, [this.hint = '']);
  final int value;
  final String hint;
}

const _notes = [
  _Note(500000, '2만동과 비슷해요'),
  _Note(200000),
  _Note(100000),
  _Note(50000),
  _Note(20000, '50만동과 비슷해요'),
  _Note(10000),
  _Note(5000, '종이돈'),
  _Note(2000, '종이돈'),
  _Note(1000, '종이돈'),
];

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.palette;
    final total = s.notesTotal;

    return Column(
      children: [
        const PageHeader(title: '지폐 세기'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: navyCard(p),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('지갑 속 합계', style: TextStyle(fontSize: 13, color: p.onNavyMuted)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${fmt(total)}동',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: p.onNavy,
                                fontFeatures: tabular,
                              ),
                            ),
                          ),
                          Text(
                            s.rate == null ? '환율 없음' : '≈ ${fmt(total / s.rate!)}원',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.gold, fontFeatures: tabular),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: total == 0 ? null : s.resetNotes,
                      style: TextButton.styleFrom(foregroundColor: p.onNavyMuted),
                      child: const Text('비우기'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final n in _notes) ...[
                _NoteTile(n, s.noteCounts[n.value] ?? 0),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile(this.note, this.count);
  final _Note note;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = AppScope.read(context);
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: '${fmt(note.value)}동 지폐 크게 보기',
            child: GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.85),
                builder: (ctx) => _NoteViewer(note.value),
              ),
              child: Banknote(value: note.value, width: 92),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fmt(note.value)}동',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.ink, fontFeatures: tabular),
                ),
                if (note.hint.isNotEmpty)
                  Text(
                    note.hint,
                    maxLines: 2,
                    style: TextStyle(fontSize: 12, color: p.muted, height: 1.3),
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: '한 장 빼기',
            onPressed: count == 0 ? null : () => s.changeNote(note.value, -1),
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.ink, fontFeatures: tabular),
            ),
          ),
          IconButton.filled(
            tooltip: '한 장 더하기',
            onPressed: () {
              HapticFeedback.selectionClick();
              s.changeNote(note.value, 1);
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// 지폐 앞면 + 뒷면 크게 보기
class _NoteViewer extends StatelessWidget {
  const _NoteViewer(this.value);
  final int value;

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width - 40).clamp(0.0, 420.0);
    const label = TextStyle(color: Colors.white70, fontSize: 13);
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${fmt(value)}동',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Banknote(value: value, width: w),
            const SizedBox(height: 6),
            const Text('앞면', style: label),
            const SizedBox(height: 14),
            Banknote(value: value, width: w, back: true),
            const SizedBox(height: 6),
            const Text('뒷면', style: label),
            const SizedBox(height: 20),
            const Text('누르면 닫혀요', style: label),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 보여주기 카드 ─────────────────────────

class Phrase {
  const Phrase(this.ko, this.vi, this.icon, {this.no = false, this.sign});
  final String ko, vi;

  /// 3D 그림 (Microsoft Fluent Emoji, MIT)
  final String icon;

  /// 그림 위에 빨간 금지 표시
  final bool no;

  /// 전체 화면에 그림 대신 보여줄 안내판 이미지
  final String? sign;
}

const phrases = [
  Phrase('고수 빼주세요', 'Không cho rau mùi', 'assets/phrases/herb.png', no: true, sign: 'assets/herb.png'),
  Phrase('얼음 빼주세요', 'Không đá', 'assets/phrases/ice.png', no: true),
  Phrase('안 맵게 해주세요', 'Không cay', 'assets/phrases/pepper.png', no: true),
  Phrase('덜 달게 해주세요', 'Ít ngọt', 'assets/phrases/candy.png'),
  Phrase('얼마예요?', 'Bao nhiêu tiền?', 'assets/phrases/money.png'),
  Phrase('계산해 주세요', 'Tính tiền', 'assets/phrases/receipt.png'),
  Phrase('깎아 주실 수 있어요?', 'Bớt được không?', 'assets/phrases/label.png'),
  Phrase('화장실 어디예요?', 'Nhà vệ sinh ở đâu?', 'assets/phrases/toilet.png'),
];

/// 그림 + (필요하면) 빨간 금지 표시
class PhraseIcon extends StatelessWidget {
  const PhraseIcon(this.phrase, {super.key, required this.size});
  final Phrase phrase;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.all(phrase.no ? size * 0.14 : 0),
          child: Image.asset(phrase.icon, fit: BoxFit.contain),
        ),
        if (phrase.no) CustomPaint(painter: _NoSignPainter()),
      ],
    ),
  );
}

class _NoSignPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final stroke = s.width * 0.085;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xE6D32F2F);
    final r = s.width / 2 - stroke / 2;
    final center = Offset(s.width / 2, s.height / 2);
    c.drawCircle(center, r, paint);
    final d = r * 0.7071;
    c.drawLine(center + Offset(-d, -d), center + Offset(d, d), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class PhrasesPage extends StatelessWidget {
  const PhrasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = Theme.of(context).brightness == Brightness.light ? p.navyHi : p.gold;
    return Column(
      children: [
        const PageHeader(title: '보여주기'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('누르면 크게 떠요. 직원에게 화면을 보여주세요.', style: TextStyle(fontSize: 13, color: p.muted)),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.02,
            ),
            itemCount: phrases.length,
            itemBuilder: (context, i) {
              final ph = phrases[i];
              return Material(
                color: p.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(color: p.line),
                ),
                child: InkWell(
                  customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      opaque: true,
                      transitionDuration: const Duration(milliseconds: 220),
                      pageBuilder: (_, _, _) => PhraseScreen(ph),
                      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Hero(tag: ph.icon, child: PhraseIcon(ph, size: 64)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ph.ko,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ph.vi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: accent),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 직원에게 보여주는 전체 화면 (항상 밝은 배경으로 잘 보이게)
class PhraseScreen extends StatelessWidget {
  const PhraseScreen(this.phrase, {super.key});
  final Phrase phrase;

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFF5D6577);
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Expanded(
                  child: phrase.sign != null
                      ? Image.asset(phrase.sign!, fit: BoxFit.contain)
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Hero(tag: phrase.icon, child: PhraseIcon(phrase, size: 200)),
                              const SizedBox(height: 36),
                              Text(
                                phrase.vi,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 52,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10172A),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(phrase.ko, style: const TextStyle(fontSize: 20, color: muted)),
                            ],
                          ),
                        ),
                ),
                const Text('화면을 누르면 닫혀요', style: TextStyle(fontSize: 13, color: muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 메모 ─────────────────────────

class MemoPage extends StatefulWidget {
  const MemoPage({super.key});

  @override
  State<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  TextEditingController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl ??= TextEditingController(text: AppScope.read(context).memo);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = AppScope.read(context);
    return Column(
      children: [
        const PageHeader(title: '메모'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Panel(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
              child: TextField(
                controller: _ctrl,
                onChanged: s.setMemo,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: TextStyle(fontSize: 16, height: 1.6, color: p.ink),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '여행 메모를 적어 보세요',
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('입력하면 자동으로 저장돼요', style: TextStyle(fontSize: 12, color: p.muted)),
        ),
      ],
    );
  }
}
