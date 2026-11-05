import 'package:flutter/material.dart';
import 'package:glide/core/constants/app_constants.dart';
import 'package:glide/features/detection/domain/entities/detection.dart';

/// Draws a box and label over each detection. Box coordinates are normalised
/// to the upright camera frame, so this must be laid out exactly over the
/// preview (as `CameraPreview`'s child).
///
/// Purely visual: screen reader users get the same information from the
/// preview's semantics label and, from Milestone 3, spoken alerts.
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({required this.detections, super.key});

  final List<Detection> detections;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.infinite,
        painter: DetectionPainter(
          detections: detections,
          colors: (
            close: scheme.error,
            near: Colors.amber,
            far: scheme.primary,
          ),
          textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

typedef BandColors = ({Color close, Color near, Color far});

class DetectionPainter extends CustomPainter {
  DetectionPainter({
    required this.detections,
    required this.colors,
    required this.textStyle,
  });

  final List<Detection> detections;
  final BandColors colors;
  final TextStyle textStyle;

  Color colorFor(Detection d) => switch (d.bandFor(
    closeMeters: AppConstants.closeDistanceMeters,
    nearMeters: AppConstants.nearDistanceMeters,
  )) {
    DistanceBand.close => colors.close,
    DistanceBand.near => colors.near,
    DistanceBand.far => colors.far,
  };

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      final color = colorFor(d);
      final rect = Rect.fromLTRB(
        d.left * size.width,
        d.top * size.height,
        d.right * size.width,
        d.bottom * size.height,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );

      final label = TextPainter(
        text: TextSpan(
          text: '${d.label} ${d.distanceMeters.toStringAsFixed(1)} m',
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      // Above the box if there's room, otherwise just inside it.
      final top = rect.top - label.height - 4 >= 0
          ? rect.top - label.height - 4
          : rect.top + 4;
      final background = Rect.fromLTWH(
        rect.left,
        top,
        label.width + 8,
        label.height + 4,
      );
      canvas.drawRect(background, Paint()..color = color);
      label.paint(canvas, Offset(background.left + 4, background.top + 2));
    }
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) =>
      oldDelegate.detections != detections || oldDelegate.colors != colors;
}
