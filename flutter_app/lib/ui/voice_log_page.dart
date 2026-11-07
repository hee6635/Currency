import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/voice_log.dart';
import 'common.dart';
import 'theme.dart';

/// 음성 기록: 말할 때마다(실패 포함) 폰이 들은 말과 결과.
/// 백업하면 파일로 내보내고 앱 안의 기록은 비운다.
class VoiceLogPage extends StatelessWidget {
  const VoiceLogPage({super.key, required this.log});
  final VoiceLog log;

  Future<void> _backup(BuildContext context) async {
    if (log.entries.isEmpty) return toast(context, '기록이 없어요');
    final text = log.export();
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) toast(context, '기록을 복사했어요');
      return;
    }
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        'voice_log_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.txt';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(text);

    final r = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/plain')],
        subject: '베트남 환율 음성 기록',
      ),
    );
    if (!context.mounted) return;
    var clear = r.status == ShareResultStatus.success;
    if (r.status == ShareResultStatus.unavailable) {
      // 보냈는지 폰이 알려주지 않는 경우: 물어보기
      clear =
          await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('파일을 보냈나요?'),
              content: const Text('보냈다면 앱 안의 음성 기록을 비울게요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('아니요'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('보냈어요, 비우기'),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (clear) {
      await log.clear();
      if (context.mounted) toast(context, '백업하고 앱 안의 기록을 비웠어요');
    }
  }

  Future<void> _copy(BuildContext context, {bool wrongOnly = false}) async {
    await Clipboard.setData(
      ClipboardData(text: log.export(wrongOnly: wrongOnly)),
    );
    if (context.mounted) {
      toast(context, wrongOnly ? '틀린·실패한 기록을 복사했어요' : '기록을 복사했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final items = log.entries.reversed.toList();
        final wrong = log.entries.where((e) => e.wrong || e.failed).length;
        return Scaffold(
          appBar: AppBar(
            title: Text('음성 기록 (${log.entries.length})'),
            backgroundColor: p.bg,
            surfaceTintColor: Colors.transparent,
            actions: [
              PopupMenuButton<String>(
                tooltip: '복사',
                icon: const Icon(Icons.copy_rounded),
                onSelected: (v) => _copy(context, wrongOnly: v == 'wrong'),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'all', child: Text('전체 복사')),
                  PopupMenuItem(
                    value: 'wrong',
                    child: Text('틀린·실패한 것만 복사 ($wrong)'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '길게 누르면 "틀림" 표시 · 백업하면 파일로 보내고 앱 안 기록은 비워요',
                        style: TextStyle(fontSize: 12, color: p.muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _backup(context),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('백업'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          '아직 기록이 없어요',
                          style: TextStyle(color: p.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _EntryTile(
                          items[i],
                          onLong: () => log.toggleWrong(items[i]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile(this.e, {required this.onLong});
  final VoiceLogEntry e;
  final VoidCallback onLong;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${e.at.month}/${e.at.day} ${two(e.at.hour)}:${two(e.at.minute)}:${two(e.at.second)}';
    final bad = e.failed || e.wrong;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: bad ? p.danger.withValues(alpha: 0.5) : p.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () {
          HapticFeedback.selectionClick();
          onLong();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$time · ${e.currency}',
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                  const Spacer(),
                  if (e.wrong)
                    Text(
                      '틀림',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: p.danger,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                e.heard.isEmpty ? '(아무것도 못 들음)' : '"${e.heard.first}"',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              if (e.heard.length > 1)
                Text(
                  '후보: ${e.heard.skip(1).join(' / ')}',
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              const SizedBox(height: 4),
              Text(
                e.failed ? '✗ ${e.problem ?? '반영 안 됨'}' : '→ ${e.result}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: e.failed ? p.danger : p.goldText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                e.events.join(' · '),
                style: TextStyle(fontSize: 11, color: p.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
