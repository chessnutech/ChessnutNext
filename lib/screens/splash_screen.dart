import 'dart:math' as math;

import '../l10n/localized_material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1750), () async {
      if (!mounted) return;
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF020617),
      child: Center(
        child: SizedBox(
          key: const ValueKey('splash-logo'),
          width: 196,
          child: AspectRatio(
            aspectRatio: _SplashMotionLogoPainter.viewBoxWidth /
                _SplashMotionLogoPainter.viewBoxHeight,
            child: SplashMotionLogo(animation: controller),
          ),
        ),
      ),
    );
  }
}

class SplashMotionLogo extends StatelessWidget {
  const SplashMotionLogo({required this.animation, super.key});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const ValueKey('splash-motion-logo'),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _SplashMotionLogoPainter(animation.value),
            child: child,
          );
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SplashMotionLogoPainter extends CustomPainter {
  _SplashMotionLogoPainter(this.progress);

  final double progress;

  static const double viewBoxWidth = 500;
  static const double viewBoxHeight = 163;

  static final Path _horse = _pathFromSvgData(
    'M 112 18 L 127 18 L 121 25 L 120 30 L 136 41 L 140 56 L 166 77 L 166 96 L 142 106 L 138 99 L 131 95 L 105 92 L 95 88 L 89 83 L 84 73 L 84 63 L 87 61 L 90 72 L 104 82 L 134 85 L 143 89 L 147 94 L 156 90 L 156 81 L 131 60 L 127 46 L 106 35 L 109 29 L 107 28 L 91 34 L 76 43 L 56 63 L 46 86 L 44 99 L 46 113 L 54 123 L 63 127 L 143 127 L 156 138 L 156 140 L 59 140 L 47 136 L 37 127 L 31 112 L 31 91 L 39 67 L 50 50 L 65 36 L 90 23 Z',
  );

  static final List<_SplashLogoLetter> _letters = [
    _SplashLogoLetter(
      path: _pathFromSvgData(
        'M 186 88 L 197 88 L 194 108 L 208 108 L 211 89 L 224 88 L 215 141 L 202 141 L 206 117 L 192 117 L 188 141 L 176 141 L 183 101 L 183 89 Z',
      ),
      start: 0.20,
      peak: 0.58,
      initialX: -18,
      initialRotation: -1.8,
    ),
    _SplashLogoLetter(
      path: _pathFromSvgData(
        'M 233 88 L 265 88 L 264 97 L 244 97 L 242 108 L 259 108 L 260 110 L 258 117 L 240 117 L 238 129 L 238 132 L 259 132 L 257 141 L 224 141 Z',
      ),
      start: 0.23,
      peak: 0.61,
      initialX: -16,
      initialRotation: -1.4,
    ),
    _SplashLogoLetter(
      path: _pathFromSvgData(
        'M 283 88 L 294 88 L 304 92 L 304 95 L 302 95 L 299 100 L 292 97 L 282 99 L 282 105 L 298 116 L 300 127 L 295 136 L 289 140 L 271 141 L 262 137 L 268 128 L 276 132 L 283 132 L 288 127 L 286 120 L 273 113 L 269 106 L 271 96 Z',
      ),
      start: 0.26,
      peak: 0.64,
      initialX: -14,
      initialRotation: -1.0,
    ),
    _SplashLogoLetter(
      path: _pathFromSvgData(
        'M 321 88 L 332 88 L 342 92 L 342 95 L 336 100 L 330 97 L 322 97 L 320 99 L 320 105 L 335 115 L 338 126 L 330 138 L 323 141 L 309 141 L 300 137 L 306 128 L 314 132 L 321 132 L 325 129 L 325 122 L 311 113 L 307 107 L 309 96 Z',
      ),
      start: 0.29,
      peak: 0.67,
      initialX: -12,
      initialRotation: -0.6,
    ),
    _SplashLogoLetter(
      path: _pathFromSvgData(
        'M 352 88 L 363 89 L 372 110 L 374 122 L 379 89 L 391 88 L 382 141 L 371 141 L 361 118 L 359 107 L 354 140 L 341 141 L 349 99 L 349 89 Z',
      ),
      start: 0.32,
      peak: 0.70,
      initialX: -10,
      initialRotation: -0.4,
    ),
    _SplashLogoLetter(
      path: _pathFromSvgData(
        'M 403 88 L 414 88 L 407 123 L 408 129 L 411 132 L 417 132 L 421 128 L 428 89 L 440 88 L 434 126 L 431 133 L 423 140 L 406 141 L 400 138 L 396 132 L 395 121 L 400 99 L 400 89 Z',
      ),
      start: 0.35,
      peak: 0.73,
      initialX: -8,
      initialRotation: -0.2,
    ),
    _SplashLogoLetter(
      path: _pathFromSvgData(
        'M 447 88 L 485 88 L 484 97 L 470 98 L 463 141 L 451 141 L 458 97 L 445 97 Z',
      ),
      start: 0.38,
      peak: 0.76,
      initialX: -6,
      initialRotation: 0,
    ),
  ];

  static final Path _logoClip = _buildLogoClip();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / viewBoxWidth,
      size.height / viewBoxHeight,
    );
    final dx = (size.width - viewBoxWidth * scale) / 2;
    final dy = (size.height - viewBoxHeight * scale) / 2;

    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale);

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    _paintTransformedPath(
      canvas,
      path: _horse,
      paint: paint,
      opacity: _horseOpacity(progress),
      translateX: _horseTranslateX(progress),
      translateY: _horseTranslateY(progress),
      scale: _horseScale(progress),
    );

    for (final letter in _letters) {
      final t = _letterProgress(progress, letter.start, letter.peak);
      _paintTransformedPath(
        canvas,
        path: letter.path,
        paint: paint,
        opacity: Curves.easeOutCubic.transform(t),
        translateX:
            _lerpDouble(letter.initialX, 0, Curves.easeOutCubic.transform(t)),
        translateY: _letterTranslateY(t),
        rotationDegrees: _lerpDouble(
            letter.initialRotation, 0, Curves.easeOutCubic.transform(t)),
        scale: _letterScale(t),
      );
    }

    _paintSheen(canvas);

    canvas.restore();
  }

  static void _paintTransformedPath(
    Canvas canvas, {
    required Path path,
    required Paint paint,
    required double opacity,
    double translateX = 0,
    double translateY = 0,
    double scale = 1,
    double rotationDegrees = 0,
  }) {
    if (opacity <= 0) return;

    final bounds = path.getBounds();
    final center = bounds.center;
    canvas.save();
    canvas.translate(center.dx + translateX, center.dy + translateY);
    if (rotationDegrees != 0) {
      canvas.rotate(rotationDegrees * math.pi / 180);
    }
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    final transformedPaint = Paint()
      ..color = paint.color.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..style = paint.style
      ..isAntiAlias = paint.isAntiAlias;
    canvas.drawPath(path, transformedPaint);
    canvas.restore();
  }

  void _paintSheen(Canvas canvas) {
    final sheenProgress = ((progress - 0.54) / 0.30).clamp(0.0, 1.0);
    if (sheenProgress <= 0 || sheenProgress >= 1) return;

    final opacity = math.sin(sheenProgress * math.pi) * 0.28;
    final x =
        _lerpDouble(-70, 560, Curves.easeOutCubic.transform(sheenProgress));
    final sheenPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas
      ..save()
      ..clipPath(_logoClip)
      ..translate(x, 0)
      ..rotate(13 * math.pi / 180);
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-80, -30, 34, 223),
      const Radius.circular(17),
    );
    canvas.drawRRect(rect, sheenPaint);
    canvas.restore();
  }

  static Path _buildLogoClip() {
    final clip = Path()..fillType = PathFillType.nonZero;
    clip.addPath(_horse, Offset.zero);
    for (final letter in _letters) {
      clip.addPath(letter.path, Offset.zero);
    }
    return clip;
  }

  static double _horseOpacity(double p) {
    if (p <= 0.08) return 0;
    if (p >= 0.55) return 1;
    return Curves.easeOutCubic.transform(((p - 0.08) / 0.47).clamp(0, 1));
  }

  static double _horseTranslateX(double p) {
    if (p < 0.20) return _lerpDouble(-16, -20, p / 0.20);
    if (p < 0.55) {
      return _lerpDouble(
          -20, 1, Curves.easeOutCubic.transform((p - 0.20) / 0.35));
    }
    if (p < 0.78) {
      return _lerpDouble(
          1, 0, Curves.easeOutCubic.transform((p - 0.55) / 0.23));
    }
    return 0;
  }

  static double _horseTranslateY(double p) {
    if (p < 0.20) return _lerpDouble(7, 8, p / 0.20);
    if (p < 0.55) {
      return _lerpDouble(
          8, -1, Curves.easeOutCubic.transform((p - 0.20) / 0.35));
    }
    if (p < 0.78) {
      return _lerpDouble(
          -1, 0.3, Curves.easeOutCubic.transform((p - 0.55) / 0.23));
    }
    return 0;
  }

  static double _horseScale(double p) {
    if (p < 0.20) return _lerpDouble(0.94, 0.92, p / 0.20);
    if (p < 0.55) {
      return _lerpDouble(
          0.92, 1.018, Curves.easeOutCubic.transform((p - 0.20) / 0.35));
    }
    if (p < 0.78) {
      return _lerpDouble(
          1.018, 0.997, Curves.easeOutCubic.transform((p - 0.55) / 0.23));
    }
    return 1;
  }

  static double _letterProgress(double p, double start, double peak) {
    if (p <= start) return 0;
    if (p >= 1) return 1;
    return ((p - start) / (peak - start)).clamp(0.0, 1.0);
  }

  static double _letterTranslateY(double t) {
    if (t < 0.88) {
      return _lerpDouble(8, -1, Curves.easeOutCubic.transform(t / 0.88));
    }
    return _lerpDouble(-1, 0, Curves.easeOutCubic.transform((t - 0.88) / 0.12));
  }

  static double _letterScale(double t) {
    if (t < 0.88) {
      return _lerpDouble(0.975, 1.012, Curves.easeOutCubic.transform(t / 0.88));
    }
    return _lerpDouble(
        1.012, 1, Curves.easeOutCubic.transform((t - 0.88) / 0.12));
  }

  static Path _pathFromSvgData(String data) {
    final tokens = RegExp(r'[MLZmlz]|-?\d+(?:\.\d+)?')
        .allMatches(data)
        .map((match) => match.group(0)!)
        .toList();
    final path = Path();
    var index = 0;
    var command = '';
    var current = Offset.zero;

    bool isCommand(String token) => RegExp(r'^[MLZmlz]$').hasMatch(token);
    double nextNumber() => double.parse(tokens[index++]);

    while (index < tokens.length) {
      if (isCommand(tokens[index])) {
        command = tokens[index++];
      }

      switch (command) {
        case 'M':
        case 'm':
          {
            final point = Offset(nextNumber(), nextNumber());
            current = command == 'm' ? current + point : point;
            path.moveTo(current.dx, current.dy);
            command = command == 'm' ? 'l' : 'L';
            break;
          }
        case 'L':
        case 'l':
          {
            final point = Offset(nextNumber(), nextNumber());
            current = command == 'l' ? current + point : point;
            path.lineTo(current.dx, current.dy);
            break;
          }
        case 'Z':
        case 'z':
          path.close();
          break;
        default:
          throw FormatException('Unsupported SVG path command: $command');
      }
    }
    return path;
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _SplashMotionLogoPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SplashLogoLetter {
  const _SplashLogoLetter({
    required this.path,
    required this.start,
    required this.peak,
    required this.initialX,
    required this.initialRotation,
  });

  final Path path;
  final double start;
  final double peak;
  final double initialX;
  final double initialRotation;
}
