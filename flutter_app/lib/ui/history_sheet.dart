import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/calc_history.dart';
import '../core/money.dart';
import 'common.dart';
import 'theme.dart';

/// 최근 계산 (지운 식, 앱을 닫을 때 하던 식) 목록. 누르면 입력창으로 불러온다.
void showHistorySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.surface,
    builder: (_) =>
        AppScope(state: AppScope.read(context), child: const _HistorySheet()),
  );
}

String historyTime(DateTime t, DateTime now) {
  final hm =
      '${t.hour < 12 ? '오전' : '오후'} ${t.hour % 12 == 0 ? 12 : t.hour % 12}:${t.minute.toString().padLeft(2, '0')}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return hm;
  if (diff == 1) return '어제 $hm';
  return '${t.month}/${t.day} $hm';
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.palette;
    final now = DateTime.now();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: p.ink),
                const SizedBox(width: 8),
                Text(
                  '최근 계산',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  '지울 때·앱을 닫을 때 저장 · 최근 ${CalcHistory.max}개',
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (s.history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  '아직 없어요.\n계산하던 식을 지우면 여기에 남아요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5, color: p.muted),
                ),
              ),
            for (final e in s.history)
              _HistoryTile(
                entry: e,
                time: historyTime(e.time, now),
                current: e.id == s.loadedHistoryId && s.expr.isNotEmpty,
                onTap: () {
                  HapticFeedback.selectionClick();
                  s.loadHistory(e);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.time,
    required this.current,
    required this.onTap,
  });

  final CalcEntry entry;
  final String time;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final p = context.palette;
    final total = evaluate(entry.expr);
    // 식은 입력하던 통화(지금 입력창 통화) 기준으로 보여준다
    final from = s.from;
    final to = from.other;
    final conv = total == null || s.rate == null
        ? null
        : s.convert(total, from);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: current ? p.gold.withValues(alpha: 0.14) : p.bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prettyExpr(entry.expr),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                          fontFeatures: tabular,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        current ? '$time · 지금 입력창' : time,
                        style: TextStyle(fontSize: 12, color: p.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      total == null ? '—' : '${fmt(total)}${from.unit}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                        fontFeatures: tabular,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conv == null ? '' : '≈ ${fmt(conv)}${to.unit}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: currencyAccent(to, p),
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
