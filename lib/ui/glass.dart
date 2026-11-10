import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/models.dart';
import 'theme.dart';

class MacaronBackground extends StatelessWidget {
  const MacaronBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: Color(0xFFF6F8F2)),
    child: Stack(
      children: [
        const Positioned(
          top: -150,
          right: -160,
          child: _Glow(color: Color(0xFFDDE9F5), size: 720),
        ),
        const Positioned(
          top: 160,
          left: 40,
          child: _Glow(color: Color(0xFFE0F0DF), size: 780),
        ),
        const Positioned(
          bottom: -180,
          right: 120,
          child: _Glow(color: Color(0xFFF4E8DB), size: 700),
        ),
        const Positioned(
          top: -200,
          left: 260,
          child: _Glow(color: Color(0xFFEDE4F5), size: 660),
        ),
        Positioned.fill(child: child),
      ],
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: .88), color.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 24,
    this.tint = Colors.white,
    this.opacity = .57,
    this.blur = 18,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius, opacity, blur;
  final Color tint;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF49655A).withValues(alpha: .035),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withValues(alpha: opacity + .16 > 1 ? 1 : opacity + .16),
                tint.withValues(alpha: opacity),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: .85),
              width: 1.2,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    ),
  );
}

class SoftButton extends StatelessWidget {
  const SoftButton(
    this.label, {
    super.key,
    this.icon,
    required this.onPressed,
    this.filled = false,
    this.color = Palette.mint,
    this.compact = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled, compact;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(
          horizontal: compact ? 14 : 20,
          vertical: compact ? 13 : 17,
        ),
      ),
      minimumSize: WidgetStateProperty.all(const Size(0, 44)),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? Palette.line
            : filled
            ? color
            : color.withValues(alpha: .08),
      ),
      foregroundColor: WidgetStateProperty.all(filled ? Colors.white : color),
      elevation: WidgetStateProperty.all(0),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: filled ? Colors.transparent : color.withValues(alpha: .13),
          ),
        ),
      ),
      textStyle: WidgetStateProperty.all(
        TextStyle(fontSize: compact ? 12 : 13, fontWeight: FontWeight.w600),
      ),
    );
    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 16 : 18),
            const SizedBox(width: 7),
          ],
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.color = Palette.mint,
    this.dot = false,
  });
  final String label;
  final Color color;
  final bool dot;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
    this.icon,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: Palette.mint),
        const SizedBox(width: 9),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Palette.muted,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 8), trailing!],
    ],
  );
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, this.subtitle, {super.key, this.trailing});
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: LayoutBuilder(
      builder: (context, c) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 16,
        spacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: c.maxWidth < 480
                ? c.maxWidth
                : c.maxWidth - (trailing != null ? 160 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Palette.muted,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

class AppGlyph extends StatelessWidget {
  const AppGlyph(this.app, {super.key, this.size = 42});
  final MonitoredApp app;
  final double size;
  @override
  Widget build(BuildContext context) {
    final (color, icon) = app.id.contains('aweme')
        ? (const Color(0xFF393B45), Icons.music_note_rounded)
        : app.id.contains('sgame')
        ? (const Color(0xFFC7A776), Icons.sports_esports_rounded)
        : app.id.contains('bili')
        ? (const Color(0xFFE99AB3), Icons.live_tv_rounded)
        : app.id.contains('xhs')
        ? (const Color(0xFFEA8D8F), Icons.auto_awesome_rounded)
        : (Palette.sky, Icons.apps_rounded);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * .29),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .13),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: size * .54, color: Colors.white),
    );
  }
}

class BankGlyph extends StatelessWidget {
  const BankGlyph(this.category, {super.key, this.size = 44});
  final String category;
  final double size;
  static Color colorFor(String c) => c == 'english'
      ? Palette.lavender
      : c == 'code'
      ? Palette.sky
      : c == 'math'
      ? Palette.peach
      : Palette.mint;
  @override
  Widget build(BuildContext context) {
    final color = colorFor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        category == 'english'
            ? Icons.translate_rounded
            : category == 'code'
            ? Icons.code_rounded
            : category == 'math'
            ? Icons.functions_rounded
            : Icons.menu_book_rounded,
        color: color,
        size: size * .5,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.description, {
    super.key,
    this.icon = Icons.spa_outlined,
    this.action,
  });
  final String title, description;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Palette.mintLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Palette.mint),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Palette.muted,
              height: 1.8,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    ),
  );
}

class LockArtwork extends StatelessWidget {
  const LockArtwork({super.key, this.size = 240});
  final double size;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LockPainter()),
    ),
  );
}

class _LockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240);
    final orb = const Rect.fromLTWH(12, 12, 216, 216);
    canvas.drawOval(
      orb,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.5),
          colors: [
            Colors.white.withValues(alpha: .8),
            const Color(0xFFE1EAF3).withValues(alpha: .45),
            const Color(0xFFC6DCD4).withValues(alpha: .3),
          ],
        ).createShader(orb),
    );
    canvas.drawOval(
      orb.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withValues(alpha: .1),
            Colors.white.withValues(alpha: .85),
          ],
        ).createShader(orb),
    );
    canvas.save();
    canvas.translate(120, 116);
    canvas.rotate(-.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-35, -65, 70, 91),
        const Radius.circular(34),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..color = const Color(0xFFA6C5B9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-35, -65, 70, 91),
        const Radius.circular(34),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..shader = const LinearGradient(
          colors: [Color(0xFFF4FAF5), Color(0xFFB8D5C8), Color(0xFFE7F3EE)],
        ).createShader(const Rect.fromLTWH(-44, -68, 88, 100)),
    );
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-57, -12, 114, 94),
      const Radius.circular(26),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 8)),
      Paint()
        ..color = const Color(0xFF729C8C).withValues(alpha: .15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2FBF5), Color(0xFFAFD3BF), Color(0xFFCCE4D6)],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..shader = const LinearGradient(
          colors: [Colors.white, Color(0xFFB7D0C1), Colors.white],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-47, -2, 94, 35),
        const Radius.circular(17),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .62),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(body.outerRect),
    );
    canvas.drawCircle(
      const Offset(0, 30),
      9,
      Paint()..color = const Color(0xFF789C8B),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, 34, 8, 16),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF789C8B),
    );
    canvas.restore();
    _spark(canvas, const Offset(203, 57), 11, const Color(0xFFB6A4D4));
    _spark(canvas, const Offset(43, 173), 7, const Color(0xFFBCB2D5));
    _spark(canvas, const Offset(58, 38), 5, const Color(0xFFE5C298));
    canvas.drawCircle(
      const Offset(204, 174),
      6,
      Paint()..color = const Color(0xFFF1D1B9),
    );
    canvas.save();
    canvas.translate(36, 107);
    canvas.rotate(-.6);
    canvas.drawOval(
      const Rect.fromLTWH(-8, -15, 16, 30),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFD7EAD8), Color(0xFFAECBAF)],
        ).createShader(const Rect.fromLTWH(-8, -15, 16, 30)),
    );
    canvas.drawLine(
      const Offset(0, -8),
      const Offset(0, 17),
      Paint()
        ..color = Colors.white.withValues(alpha: .8)
        ..strokeWidth = 1,
    );
    canvas.restore();
    canvas.restore();
  }

  void _spark(Canvas c, Offset o, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final radius = i.isEven ? r : r * .28;
      final x = o.dx + math.cos(a) * radius, y = o.dy + math.sin(a) * radius;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    c.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
  );
}

String readableError(Object error) => error.toString().replaceFirst(
  RegExp(r'^(Bad state: |FormatException: |Exception: )'),
  '',
);
