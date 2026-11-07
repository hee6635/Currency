import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/voice_log.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'teach_dialog.dart';
import 'theme.dart';

/// 음성 기록: 말할 때마다(실패 포함) 폰이 들은 말과 결과.
/// 백업하면 파일로 내보내고 앱 안의 기록은 비운다.
class VoiceLogPage extends StatelessWidget {
  const VoiceLogPage({super.key, required this.log, required this.state});
  final VoiceLog log;
  final AppState state;

  /// GitHub 이슈 작성 화면을 기록이 채워진 채로 연다 (로그인된 계정으로 "Submit"만 누르면 됨).
  /// 앱 안에 GitHub 열쇠를 넣지 않기 위해 이렇게 한다. 4시간마다 AI가 읽고 보정 규칙을 고친다.
  Future<void> _upload(BuildContext context) async {
    if (log.entries.isEmpty) return toast(context, '기록이 없어요');
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    // 주소 길이 제한 때문에 틀린·실패한 것 우선, 최근 것부터 약 5,000자까지
    final pick = <VoiceLogEntry>[];
    var len = 0;
    final pool = [
      ...log.entries.reversed.where((e) => e.wrong || e.failed),
      ...log.entries.reversed.where((e) => !(e.wrong || e.failed)),
    ];
    for (final e in pool) {
      final t = e.toText();
      if (len + t.length > 5000) break;
      pick.add(e);
      len += t.length + 1;
    }
    final learned = state.learned.entries
        .map((e) => '${e.key} → ${e.value}')
        .join(', ');
    final body = [
      '<!-- voice-log -->',
      '앱에서 보낸 음성 기록이에요. (전체 ${log.entries.length}개 중 ${pick.length}개, 틀린·실패한 것 먼저)',
      '',
      '```',
      for (final e in pick) e.toText(),
      '```',
      if (learned.isNotEmpty) '\n폰에서 가르친 말: $learned',
      '\n현재 보정 규칙 버전: ${state.rules.version}',
    ].join('\n');
    final url = Uri.https('github.com', '/hee6635/Currency/issues/new', {
      'title':
          '[voice-log] 음성 기록 ${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)} (${pick.length}개)',
      'labels': 'voice-log',
      'body': body,
    });
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) toast(context, 'GitHub 화면을 열 수 없어요');
  }

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
              IconButton(
                tooltip: 'GitHub에 기록 올리기',
                icon: const Icon(Icons.cloud_upload_outlined),
                onPressed: () => _upload(context),
              ),
              PopupMenuButton<String>(
                tooltip: '복사',
                icon: const Icon(Icons.copy_rounded),
                onSelected: (v) {
                  if (v == 'forget') {
                    state.forgetLearned();
                    toast(context, '가르친 말을 모두 지웠어요');
                    return;
                  }
                  _copy(context, wrongOnly: v == 'wrong');
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'all', child: Text('전체 복사')),
                  PopupMenuItem(
                    value: 'wrong',
                    child: Text('틀린·실패한 것만 복사 ($wrong)'),
                  ),
                  PopupMenuItem(
                    value: 'forget',
                    enabled: state.learned.isNotEmpty,
                    child: Text('가르친 말 모두 지우기 (${state.learned.length})'),
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
                        '누르면 원래 숫자 가르치기 · 길게 누르면 "틀림" · ☁ GitHub에 올리기 · 백업하면 앱 안 기록은 비워요',
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
                          onTap: () async {
                            final e = items[i];
                            final heard = e.heard.isEmpty ? '' : e.heard.first;
                            if (heard.isEmpty) {
                              return toast(context, '들린 말이 없어서 가르칠 수 없어요');
                            }
                            final n = await askOriginalNumber(context, heard);
                            if (n == null) return;
                            state.teach(heard, n, apply: false);
                            if (!e.wrong) log.toggleWrong(e);
                            if (context.mounted) {
                              toast(context, '"$heard" → $n 으로 기억할게요');
                            }
                          },
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
  const _EntryTile(this.e, {required this.onLong, required this.onTap});
  final VoiceLogEntry e;
  final VoidCallback onLong;
  final VoidCallback onTap;

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
        onTap: onTap,
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
