import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/udhar_repository.dart';
import '../theme/app_theme.dart';
import 'customer_reminder_dialog.dart';

class AnimatedReminderButton extends StatefulWidget {
  final Customer customer;
  final UdharRepository repository;
  final bool isCompact;

  const AnimatedReminderButton({
    super.key,
    required this.customer,
    required this.repository,
    this.isCompact = false,
  });

  @override
  State<AnimatedReminderButton> createState() => _AnimatedReminderButtonState();
}

class _AnimatedReminderButtonState extends State<AnimatedReminderButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPressed(BuildContext context, bool hasDues) {
    if (!hasDues) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No dues pending for ${widget.customer.name}! All records are clear.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.paidText,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    CustomerReminderDialog.show(
      context,
      customer: widget.customer,
      repository: widget.repository,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingBalance = widget.repository.getCustomerPendingBalance(
      widget.customer.id,
    );
    final hasDues = pendingBalance > 0.001;

    // Dimensions matching standard 36x36 action badge container with 22px Earth globe
    const double containerSize = 36.0;
    const double planetSize = 22.0;
    const double radiusX = 16.0;
    const double radiusY = 7.5;

    return Tooltip(
      message: hasDues ? 'Send Dues Reminder' : 'No Dues Pending',
      child: InkWell(
        onTap: () => _onPressed(context, hasDues),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: containerSize,
          height: containerSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.cardBorder.withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          child: SizedBox(
            width: containerSize,
            height: containerSize,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 1. Back Z-axis Earth Orbit Rocket Layer (passes behind Earth globe)
                if (hasDues)
                  _buildNonRotatingOrbitalRocket(
                    radiusX: radiusX,
                    radiusY: radiusY,
                    isFrontLayer: false,
                    iconSize: 10,
                  ),

                // 2. Center Edge-to-Edge Earth Globe Sphere (22x22 matching 20px action icons)
                Container(
                  width: planetSize,
                  height: planetSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow:
                        hasDues
                            ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF0288D1,
                                ).withValues(alpha: 0.45),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                            : null,
                  ),
                  child: CustomPaint(
                    size: const Size(planetSize, planetSize),
                    painter: EarthGlobePainter(hasDues: hasDues),
                  ),
                ),

                // 3. Front Z-axis Earth Orbit Rocket Layer (passes in front of Earth globe)
                if (hasDues)
                  _buildNonRotatingOrbitalRocket(
                    radiusX: radiusX,
                    radiusY: radiusY,
                    isFrontLayer: true,
                    iconSize: 10,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNonRotatingOrbitalRocket({
    required double radiusX,
    required double radiusY,
    required bool isFrontLayer,
    required double iconSize,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        final t = val * 2 * math.pi;

        // Earth orbital tilt angle (-18 degrees)
        const phi = -0.31;

        final cosT = math.cos(t);
        final sinT = math.sin(t);
        final cosPhi = math.cos(phi);
        final sinPhi = math.sin(phi);

        // Unrotated orbit coordinates
        final x0 = radiusX * cosT;
        final y0 = radiusY * sinT;

        // Tilted orbit coordinates
        final dx = x0 * cosPhi - y0 * sinPhi;
        final dy = x0 * sinPhi + y0 * cosPhi;

        // Z-axis 3D depth value relative to Earth globe
        final z = sinT * cosPhi + cosT * sinPhi;
        final isFront = z >= 0;

        // Filter depth layer: render in front vs behind Earth sphere
        if (isFrontLayer != isFront) {
          return const SizedBox.shrink();
        }

        // 3D Depth scaling & opacity
        final scale = 0.68 + (z + 1.0) / 2.0 * 0.67;
        final opacity = (0.45 + (z + 1.0) / 2.0 * 0.55).clamp(0.0, 1.0);

        // Fixed single rocket color using Application Theme Color (AppTheme.saffronPrimary)
        const rocketColor = AppTheme.saffronPrimary;

        // Rocket ONLY revolves (translates along orbit) and DOES NOT ROTATE
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: rocketColor.withValues(
                        alpha: isFront ? 0.75 : 0.3,
                      ),
                      blurRadius: isFront ? 5 : 2,
                      spreadRadius: isFront ? 1 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  size: iconSize,
                  color: rocketColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter to render edge-to-edge Earth Globe view with ocean, continents, ice caps, and atmospheric glow
class EarthGlobePainter extends CustomPainter {
  final bool hasDues;

  EarthGlobePainter({required this.hasDues});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // Clip to circle so Earth Globe texture fills edge-to-edge
    final clipPath = Path()..addOval(rect);
    canvas.clipPath(clipPath);

    if (hasDues) {
      // 1. Deep Blue Ocean Base Gradient (Edge-to-Edge)
      final oceanPaint =
          Paint()
            ..shader = const RadialGradient(
              colors: [
                Color(0xFF2196F3), // Shallow Coastal Blue
                Color(0xFF1565C0), // Deep Ocean Blue
                Color(0xFF0D47A1), // Abyssal Blue
              ],
              center: Alignment(-0.35, -0.35),
              radius: 0.85,
            ).createShader(rect);
      canvas.drawRect(rect, oceanPaint);

      // 2. Earth Continent Landmass Shapes (Lush Green)
      final landPaint =
          Paint()
            ..color = const Color(0xFF4CAF50)
            ..style = PaintingStyle.fill;

      // Eurasia / Asia
      final p1 =
          Path()
            ..moveTo(size.width * 0.10, size.height * 0.25)
            ..cubicTo(
              size.width * 0.35,
              size.height * 0.10,
              size.width * 0.70,
              size.height * 0.20,
              size.width * 0.90,
              size.height * 0.35,
            )
            ..cubicTo(
              size.width * 0.75,
              size.height * 0.55,
              size.width * 0.40,
              size.height * 0.50,
              size.width * 0.15,
              size.height * 0.40,
            )
            ..close();
      canvas.drawPath(p1, landPaint);

      // Americas / Africa
      final p2 =
          Path()
            ..moveTo(size.width * 0.30, size.height * 0.48)
            ..cubicTo(
              size.width * 0.65,
              size.height * 0.45,
              size.width * 0.85,
              size.height * 0.70,
              size.width * 0.60,
              size.height * 0.88,
            )
            ..cubicTo(
              size.width * 0.40,
              size.height * 0.80,
              size.width * 0.25,
              size.height * 0.65,
              size.width * 0.30,
              size.height * 0.48,
            )
            ..close();
      canvas.drawPath(p2, landPaint);

      // East Islands landmass
      canvas.drawOval(
        Rect.fromLTWH(
          size.width * 0.68,
          size.height * 0.62,
          size.width * 0.22,
          size.height * 0.18,
        ),
        landPaint..color = const Color(0xFF66BB6A),
      );

      // 3. Polar Ice Caps
      final icePaint =
          Paint()..color = const Color(0xFFE0F7FA).withValues(alpha: 0.9);
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.04),
        size.width * 0.25,
        icePaint,
      );
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.96),
        size.width * 0.20,
        icePaint,
      );

      // 4. Atmosphere Cloud Swirl Streaks
      final cloudPaint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.45);

      final cloudPath =
          Path()
            ..moveTo(size.width * 0.05, size.height * 0.30)
            ..quadraticBezierTo(
              size.width * 0.4,
              size.height * 0.18,
              size.width * 0.75,
              size.height * 0.32,
            )
            ..moveTo(size.width * 0.25, size.height * 0.68)
            ..quadraticBezierTo(
              size.width * 0.6,
              size.height * 0.78,
              size.width * 0.95,
              size.height * 0.62,
            );
      canvas.drawPath(cloudPath, cloudPaint);

      // 5. Spherical 3D Lighting Overlay (Light source top-left)
      final lightPaint =
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.38),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.50),
              ],
              stops: const [0.0, 0.5, 1.0],
              center: const Alignment(-0.4, -0.4),
              radius: 0.85,
            ).createShader(rect);
      canvas.drawRect(rect, lightPaint);

      // 6. Earth Atmosphere Cyan Outer Glow Rim
      final rimPaint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = const Color(0xFF4FC3F7);
      canvas.drawCircle(center, radius - 0.4, rimPaint);
    } else {
      // Dormant Gray Moon Shading
      final moonPaint =
          Paint()
            ..shader = const RadialGradient(
              colors: [
                Color(0xFFB0BEC5),
                Color(0xFF78909C),
                Color(0xFF37474F),
              ],
              center: Alignment(-0.35, -0.35),
              radius: 0.85,
            ).createShader(rect);
      canvas.drawRect(rect, moonPaint);

      final rimPaint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = Colors.grey.withValues(alpha: 0.4);
      canvas.drawCircle(center, radius - 0.4, rimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant EarthGlobePainter oldDelegate) =>
      oldDelegate.hasDues != hasDues;
}
