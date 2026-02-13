/// KozAlma AI — Edge Volume Controller Widget.
///
/// Invisible left/right touch zones for volume control.
/// - 1 tap on left/right → speaks volume hint
/// - 2 taps on right → increase volume
/// - 2 taps on left  → decrease volume
library;

import 'package:flutter/material.dart';
import '../services/tts_service.dart';

class EdgeVolumeController extends StatefulWidget {
  final TtsService ttsService;
  final String lang;
  final Widget child;

  const EdgeVolumeController({
    super.key,
    required this.ttsService,
    required this.lang,
    required this.child,
  });

  @override
  State<EdgeVolumeController> createState() => _EdgeVolumeControllerState();
}

class _EdgeVolumeControllerState extends State<EdgeVolumeController> {
  DateTime? _lastTapLeft;
  DateTime? _lastTapRight;

  static const _doubleTapWindow = Duration(milliseconds: 400);

  String _hint() => widget.lang == 'ru'
      ? 'Для изменения громкости дважды нажмите на левую или правую сторону экрана'
      : 'Дыбыс деңгейін өзгерту үшін экранның сол немесе оң жағын екі рет басыңыз';

  String _volUp() => widget.lang == 'ru' ? 'Громкость увеличена' : 'Дыбыс деңгейі жоғарылады';
  String _volDown() => widget.lang == 'ru' ? 'Громкость уменьшена' : 'Дыбыс деңгейі төмендеді';
  String _volMax() => widget.lang == 'ru' ? 'Максимальная громкость' : 'Ең жоғарғы дыбыс деңгейі';
  String _volMin() => widget.lang == 'ru' ? 'Минимальная громкость' : 'Ең төменгі дыбыс деңгейі';

  void _onTapLeft() {
    final now = DateTime.now();
    if (_lastTapLeft != null && now.difference(_lastTapLeft!) < _doubleTapWindow) {
      _lastTapLeft = null;
      _doDecreaseVolume();
    } else {
      _lastTapLeft = now;
      widget.ttsService.speak(_hint(), lang: widget.lang);
    }
  }

  void _onTapRight() {
    final now = DateTime.now();
    if (_lastTapRight != null && now.difference(_lastTapRight!) < _doubleTapWindow) {
      _lastTapRight = null;
      _doIncreaseVolume();
    } else {
      _lastTapRight = now;
      widget.ttsService.speak(_hint(), lang: widget.lang);
    }
  }

  Future<void> _doIncreaseVolume() async {
    await widget.ttsService.increaseVolume();
    final msg = widget.ttsService.volume >= 1.0 ? _volMax() : _volUp();
    await widget.ttsService.speak(msg, lang: widget.lang);
  }

  Future<void> _doDecreaseVolume() async {
    await widget.ttsService.decreaseVolume();
    final msg = widget.ttsService.volume <= 0.0 ? _volMin() : _volDown();
    await widget.ttsService.speak(msg, lang: widget.lang);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Left invisible zone
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.15,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onTapLeft,
            child: const SizedBox.expand(),
          ),
        ),

        // Right invisible zone
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.15,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onTapRight,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
