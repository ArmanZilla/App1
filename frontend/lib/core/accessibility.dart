/// KozAlma AI — Accessibility Controller.
///
/// Implements the 1-tap / 2-tap accessibility pattern:
///   - 1 tap: speaks the label/hint (no action)
///   - 2 taps: executes the action
///
/// Uses a timer to distinguish between single and double tap.
library;

import 'dart:async';
import 'package:flutter/material.dart';

/// Timeout to detect whether a second tap follows the first.
const _kDoubleTapTimeout = Duration(milliseconds: 400);

/// Wraps a child widget with 1-tap/2-tap accessibility behavior.
class AccessibleTapHandler extends StatefulWidget {
  /// Label spoken on first tap.
  final String label;

  /// Hint spoken on first tap (e.g. "double tap to activate").
  final String? hint;

  /// Callback for first tap — should speak the label.
  final void Function(String text) onSpeak;

  /// Callback for double tap — executes the action.
  final VoidCallback onAction;

  /// Child widget.
  final Widget child;

  const AccessibleTapHandler({
    super.key,
    required this.label,
    this.hint,
    required this.onSpeak,
    required this.onAction,
    required this.child,
  });

  @override
  State<AccessibleTapHandler> createState() => _AccessibleTapHandlerState();
}

class _AccessibleTapHandlerState extends State<AccessibleTapHandler> {
  Timer? _tapTimer;
  int _tapCount = 0;

  void _handleTap() {
    _tapCount++;

    if (_tapCount == 1) {
      // Start timer — if no second tap arrives, treat as single tap
      _tapTimer = Timer(_kDoubleTapTimeout, () {
        // Single tap → speak label + hint
        final text = widget.hint != null
            ? '${widget.label}. ${widget.hint}'
            : widget.label;
        widget.onSpeak(text);
        _tapCount = 0;
      });
    } else if (_tapCount == 2) {
      // Double tap → cancel timer and execute action
      _tapTimer?.cancel();
      _tapCount = 0;
      widget.onAction();
    }
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: widget.label,
        hint: widget.hint ?? 'Нажмите дважды для активации',
        child: widget.child,
      ),
    );
  }
}
