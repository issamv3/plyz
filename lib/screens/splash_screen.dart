import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import 'home_screen.dart';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;
  late final Animation<double> _iconRotation;
  late final Animation<double> _iconTranslateY;
  late final Animation<double> _textFade;
  late final Animation<double> _textTranslateY;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 2100),
      vsync: this,
    )..forward();
    _iconScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );
    _iconRotation = Tween<double>(begin: 0.0, end: -math.pi / 2).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 0.70, curve: Curves.easeInOutCubic),
      ),
    );
    _iconTranslateY = Tween<double>(begin: 0.0, end: -16.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 0.70, curve: Curves.easeInOutCubic),
      ),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.50, 0.82, curve: Curves.easeOutCubic),
      ),
    );
    _textTranslateY = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.50, 0.82, curve: Curves.easeOutCubic),
      ),
    );
    PermissionService.ensureStorageAccess();
    Future.delayed(const Duration(milliseconds: 2400), _navigate);
  }
  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final playColor = theme.colorScheme.primary;
    final textColor = isDark ? Colors.white : const Color(0xFF0D0D12);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, _iconTranslateY.value),
                  child: Transform.scale(
                    scale: _iconScale.value,
                    child: Opacity(
                      opacity: _iconFade.value.clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: _iconRotation.value,
                        child: CustomPaint(
                          size: const Size(44, 44),
                          painter: _RoundedPlayTrianglePainter(
                            color: playColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Transform.translate(
                  offset: Offset(0, _textTranslateY.value),
                  child: Opacity(
                    opacity: _textFade.value.clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6), 
                      child: Text(
                        'P L Y',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
class _RoundedPlayTrianglePainter extends CustomPainter {
  final Color color;
  _RoundedPlayTrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.48;
    final path = Path();
    const cornerRadius = 4.5;
    path.moveTo(cx + r - cornerRadius * 1.5, cy - cornerRadius * 0.8);
    path.quadraticBezierTo(cx + r, cy, cx + r - cornerRadius * 1.5, cy + cornerRadius * 0.8);
    path.lineTo(cx - r * 0.5 + cornerRadius * 0.8, cy + r * 0.866 - cornerRadius * 0.5);
    path.quadraticBezierTo(
      cx - r * 0.5,
      cy + r * 0.866,
      cx - r * 0.5,
      cy + r * 0.866 - cornerRadius * 1.5,
    );
    path.lineTo(cx - r * 0.5, cy - r * 0.866 + cornerRadius * 1.5);
    path.quadraticBezierTo(
      cx - r * 0.5,
      cy - r * 0.866,
      cx - r * 0.5 + cornerRadius * 0.8,
      cy - r * 0.866 + cornerRadius * 0.5,
    );
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant _RoundedPlayTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
