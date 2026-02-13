/// KozAlma AI — Accessible Button Widget.
///
/// Large, high-contrast button with 1-tap (speak) / 2-tap (action) pattern.
/// Supports both circular and rounded-rectangle shapes.
library;

import 'package:flutter/material.dart';
import '../core/accessibility.dart';
import '../services/tts_service.dart';

class AccessibleButton extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData icon;
  final VoidCallback onAction;
  final TtsService ttsService;
  final String lang;

  /// Whether this is the primary (accent) button.
  final bool isPrimary;

  /// Circular mode: renders as a circle with given diameter.
  final bool circular;
  final double diameter;

  /// Icon size inside the button.
  final double iconSize;

  /// Optional subtitle shown below the button.
  final String? subtitle;

  const AccessibleButton({
    super.key,
    required this.label,
    this.hint,
    required this.icon,
    required this.onAction,
    required this.ttsService,
    this.lang = 'ru',
    this.isPrimary = true,
    this.circular = false,
    this.diameter = 160,
    this.iconSize = 32,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (circular) {
      return _buildCircular(context);
    }
    return _buildRectangular(context);
  }

  Widget _buildCircular(BuildContext context) {
    return AccessibleTapHandler(
      label: label,
      hint: hint,
      onSpeak: (text) => ttsService.speak(text, lang: lang),
      onAction: onAction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isPrimary
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7C4DFF), Color(0xFF536DFE)],
                    )
                  : null,
              color: isPrimary ? null : const Color(0xFF1E1E2E),
              border: isPrimary
                  ? null
                  : Border.all(color: const Color(0xFF7C4DFF), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: isPrimary
                      ? const Color(0xFF7C4DFF).withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.3),
                  blurRadius: isPrimary ? 28 : 12,
                  spreadRadius: isPrimary ? 4 : 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 14),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRectangular(BuildContext context) {
    return AccessibleTapHandler(
      label: label,
      hint: hint,
      onSpeak: (text) => ttsService.speak(text, lang: lang),
      onAction: onAction,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF536DFE)],
                )
              : null,
          color: isPrimary ? null : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(20),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xFF7C4DFF), width: 2),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: iconSize),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
