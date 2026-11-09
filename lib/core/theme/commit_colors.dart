import 'package:flutter/material.dart';

/// Custom colours that live outside ColorScheme (PRD §5.6–5.8).
@immutable
class CommitColors extends ThemeExtension<CommitColors> {
  final Color surfaceRaised, border, textSecondary, onAccent;
  final Color gradientEnd, success, warning, info;
  final Color idea, project, hackathon, resource;
  final List<Color> heat;

  const CommitColors({
    required this.surfaceRaised,
    required this.border,
    required this.textSecondary,
    required this.onAccent,
    required this.gradientEnd,
    required this.success,
    required this.warning,
    required this.info,
    required this.idea,
    required this.project,
    required this.hackathon,
    required this.resource,
    required this.heat,
  });

  static const dark = CommitColors(
    surfaceRaised: Color(0xFF1E2640),
    border: Color(0xFF2A3350),
    textSecondary: Color(0xFF9AA3BF),
    onAccent: Color(0xFF0B0F1A),
    gradientEnd: Color(0xFFA78BFA),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    info: Color(0xFF38BDF8),
    idea: Color(0xFFA78BFA),
    project: Color(0xFF60A5FA),
    hackathon: Color(0xFFFB923C),
    resource: Color(0xFF2DD4BF),
    heat: [Color(0xFF1E2640), Color(0xFF14532D), Color(0xFF15803D), Color(0xFF22C55E), Color(0xFF4ADE80)],
  );

  static const light = CommitColors(
    surfaceRaised: Color(0xFFE9EDF7),
    border: Color(0xFFD8DEEC),
    textSecondary: Color(0xFF475569),
    onAccent: Color(0xFFFFFFFF),
    gradientEnd: Color(0xFF7C3AED),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    info: Color(0xFF0284C7),
    idea: Color(0xFF7C3AED),
    project: Color(0xFF2563EB),
    hackathon: Color(0xFFEA580C),
    resource: Color(0xFF0D9488),
    heat: [Color(0xFFE9EDF7), Color(0xFFBBF7D0), Color(0xFF86EFAC), Color(0xFF22C55E), Color(0xFF15803D)],
  );

  Color kindColor(String kind) => switch (kind) {
        'idea' => idea,
        'project' => project,
        'hackathon' => hackathon,
        'snippet' => info,
        _ => resource,
      };

  Color heatFor(int count) => heat[count <= 0 ? 0 : count == 1 ? 1 : count <= 3 ? 2 : count <= 6 ? 3 : 4];

  @override
  CommitColors copyWith() => this;

  @override
  CommitColors lerp(CommitColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension CommitTheme on BuildContext {
  CommitColors get cc => Theme.of(this).extension<CommitColors>()!;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
