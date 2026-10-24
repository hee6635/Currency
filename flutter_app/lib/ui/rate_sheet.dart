import 'package:flutter/material.dart';

import '../core/money.dart';
import '../state/app_state.dart';
import 'theme.dart';

void showRateSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.surface,
    builder: (_) => AppScope(
      state: AppScope.read(context),
      child: const _RateSheet(),
    ),
  );
}

class _RateSheet extends StatefulWidget {
  const _RateSheet();

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  final _ctrl = TextEditingController();
  String? _inputError;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _apply(AppState s) {
    final v = parseRate(_ctrl.text);
    if (v == null) {
      setState(() => _inputError = '숫자로 입력해 주세요 (예: 18.45)');
      return;
    }
    s.setManualRate(v);
    _ctrl.clear();
    setState(() => _inputError = null);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.palette;
    final muted = TextStyle(fontSize: 13, color: p.muted, height: 1.45);

    String sourceText;
    switch (s.source) {
      case RateSource.api:
        sourceText = '${fmtTime(s.rateTime!)} 기준 · 하루 1번 갱신되는 시장 중간값';
      case RateSource.manual:
        sourceText = '${fmtTime(s.rateTime!)}에 직접 입력한 값';
      case RateSource.none:
        sourceText = '아직 환율이 없어요';
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현재 환율', style: muted),
            const SizedBox(height: 4),
            Text(
              s.rate == null ? '—' : '1원 = ${s.rate!.toStringAsFixed(2)}동',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: p.ink,
                fontFeatures: tabular,
              ),
            ),
            if (s.rate != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '1만동 ≈ ${fmt(10000 / s.rate!)}원  ·  1,000원 ≈ ${fmt(1000 * s.rate!)}동',
                  style: TextStyle(fontSize: 14, color: p.ink, fontFeatures: tabular),
                ),
              ),
            const SizedBox(height: 6),
            Text(sourceText, style: muted),
            if (s.fetchError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '업데이트 실패: ${s.fetchError}',
                  style: TextStyle(fontSize: 13, color: p.danger),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: s.fetching ? null : s.refresh,
                icon: s.fetching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(s.fetching ? '불러오는 중' : '최신 환율 가져오기'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Divider(color: p.line, height: 1),
            const SizedBox(height: 18),
            Text(
              '직접 입력',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.ink),
            ),
            const SizedBox(height: 4),
            Text('환전소 환율을 그대로 쓰고 싶을 때 (1원당 동)', style: muted),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _apply(s),
                    decoration: InputDecoration(
                      hintText: '예: 18.45',
                      errorText: _inputError,
                      filled: true,
                      fillColor: p.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: FilledButton.tonal(
                    onPressed: () => _apply(s),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('적용'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.autoUpdate,
              onChanged: s.setAutoUpdate,
              title: const Text('앱 켤 때 자동 업데이트'),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '환전 수수료 반영',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.ink),
                  ),
                ),
                Text(
                  s.feePercent == 0 ? '끔' : '${s.feePercent.toStringAsFixed(1)}%',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.goldText),
                ),
              ],
            ),
            Slider(
              value: s.feePercent,
              min: 0,
              max: 5,
              divisions: 10,
              label: '${s.feePercent.toStringAsFixed(1)}%',
              onChanged: s.setFee,
            ),
            Text(
              '환전소·카드는 보통 시장 환율보다 1~3% 불리해요. 켜면 결과 아래에 실제로 받을 금액에 가까운 값을 함께 보여줘요.',
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}
