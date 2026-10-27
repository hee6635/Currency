import 'package:flutter/material.dart';

/// 숫자 표시: 새로 붙은 글자만 아래에서 살짝 올라오며 나타난다.
/// (앞부분은 그대로 두고, 바뀐 뒷부분만 애니메이션)
class AnimatedNumberText extends StatefulWidget {
  const AnimatedNumberText(
    this.text, {
    super.key,
    required this.style,
    this.cursorColor,
  });

  final String text;
  final TextStyle style;

  /// 지정하면 끝에 깜빡이는 커서를 그린다
  final Color? cursorColor;

  @override
  State<AnimatedNumberText> createState() => _AnimatedNumberTextState();
}

class _AnimatedNumberTextState extends State<AnimatedNumberText>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  String _stable = '';
  String _fresh = '';

  @override
  void initState() {
    super.initState();
    _stable = widget.text;
    if (widget.cursorColor != null) _blink.repeat();
  }

  @override
  void didUpdateWidget(AnimatedNumberText old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    final prev = old.text, next = widget.text;
    var i = 0;
    while (i < prev.length && i < next.length && prev[i] == next[i]) {
      i++;
    }
    if (next.length > prev.length) {
      // 글자가 늘었을 때만 새 부분을 띄운다 (지울 때는 바로 반영)
      _stable = next.substring(0, i);
      _fresh = next.substring(i);
      _enter.forward(from: 0);
    } else {
      _stable = next;
      _fresh = '';
      _enter.value = 1;
    }
    // 입력하는 동안은 커서를 켜 둔다
    if (widget.cursorColor != null) {
      _blink
        ..value = 0
        ..repeat();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_stable.isNotEmpty) Text(_stable, style: style),
        if (_fresh.isNotEmpty)
          AnimatedBuilder(
            animation: _enter,
            builder: (context, child) {
              final t = Curves.easeOutCubic.transform(_enter.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * (style.fontSize ?? 30) * 0.35),
                  child: Transform.scale(
                    scale: 0.8 + 0.2 * t,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
              );
            },
            child: Text(_fresh, style: style),
          ),
        if (widget.cursorColor != null)
          AnimatedBuilder(
            animation: _blink,
            builder: (context, _) => Opacity(
              // 앞 절반은 켜짐, 뒤 절반은 꺼짐
              opacity: _blink.value < 0.55 ? 1 : 0,
              child: Container(
                margin: const EdgeInsets.only(left: 3),
                width: 2.5,
                height: (style.fontSize ?? 30) * 1.05,
                decoration: BoxDecoration(
                  color: widget.cursorColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 키패드 버튼: 누르는 순간 색이 번지고 살짝 눌렸다가, 떼면 부드럽게 돌아온다.
class PressableKey extends StatefulWidget {
  const PressableKey({
    super.key,
    required this.color,
    required this.highlight,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.shadow = true,
    this.radius = 999,
  });

  final Color color;

  /// 눌렀을 때 번지는 색
  final Color highlight;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool shadow;
  final double radius;

  @override
  State<PressableKey> createState() => _PressableKeyState();
}

class _PressableKeyState extends State<PressableKey>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
    reverseDuration: const Duration(milliseconds: 380),
  );

  void _down() => _c.forward();
  void _up() => _c.reverse();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              widget.onLongPress!();
              _up();
            },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_c.value);
          final r = BorderRadius.circular(widget.radius);
          return Transform.scale(
            scale: 1 - 0.06 * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(widget.color, widget.highlight, t * 0.55),
                borderRadius: r,
                border: Border.all(
                  color: widget.highlight.withValues(alpha: 0.55 * t),
                  width: 1.5,
                ),
                boxShadow: widget.shadow
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07 * (1 - t)),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: widget.highlight.withValues(alpha: 0.35 * t),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(child: child),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
