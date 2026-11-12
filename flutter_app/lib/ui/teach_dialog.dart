import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import 'theme.dart';

/// "이 말은 원래 얼마였나요?" — 숫자를 입력받는다. 취소하면 null.
Future<String?> askOriginalNumber(BuildContext context, String heard) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) {
      final p = c.palette;
      return StatefulBuilder(
        builder: (c, setState) {
          final digits = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
          void done() {
            if (digits.isNotEmpty && digits.length <= 12) {
              Navigator.pop(c, digits);
            }
          }

          return AlertDialog(
            title: const Text('원래 숫자 알려주기'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heard.isEmpty
                      ? '말한 숫자를 입력해 주세요.'
                      : '"$heard"(으)로 들렸어요.\n원래 말한 숫자는요?',
                  style: TextStyle(color: p.muted, height: 1.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '예: 2000'),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => done(),
                ),
                if (digits.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${fmt(int.parse(digits))}${koreanUnit(int.parse(digits)).isEmpty ? '' : ' (${koreanUnit(int.parse(digits))})'}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: p.goldText,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '다음부터 이 폰에서는 같은 말이 들리면 이 숫자로 처리해요.',
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: digits.isEmpty ? null : done,
                child: const Text('기억하기'),
              ),
            ],
          );
        },
      );
    },
  );
}
