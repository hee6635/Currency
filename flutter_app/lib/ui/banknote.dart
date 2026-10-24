import 'package:flutter/material.dart';

/// 실제 베트남 지폐 사진. assets/notes/<금액>_f.jpg(앞면), _b.jpg(뒷면)
class Banknote extends StatelessWidget {
  const Banknote({super.key, required this.value, this.width = 96, this.back = false});

  final int value;
  final double width;
  final bool back;

  static const aspect = 2.33;

  @override
  Widget build(BuildContext context) {
    final h = width / aspect;
    final radius = BorderRadius.circular(h * 0.08);
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: h * 0.08,
            offset: Offset(0, h * 0.04),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'assets/notes/${value}_${back ? 'b' : 'f'}.jpg',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
