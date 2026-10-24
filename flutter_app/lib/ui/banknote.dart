import 'package:flutter/material.dart';

/// 실제 베트남 폴리머 지폐 사진 (뒷면). assets/notes/<금액>.jpg
class Banknote extends StatelessWidget {
  const Banknote({super.key, required this.value, this.width = 96});

  final int value;
  final double width;

  static const aspect = 2.15;

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
          'assets/notes/$value.jpg',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
