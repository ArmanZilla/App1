/// KozAlma AI — App Constants.
library;

class AppConstants {
  AppConstants._();

  /// Backend API base URL (change for production).
  static const String apiBaseUrl = 'http://10.0.2.2:8000';

  /// Supported languages.
  static const List<String> languages = ['ru', 'kz'];

  /// Default language.
  static const String defaultLang = 'ru';

  /// TTS speed range.
  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;
  static const double defaultSpeed = 1.0;

  /// Light level threshold for auto-flashlight (lux).
  static const double lowLightThreshold = 30.0;

  /// Welcome messages.
  static const Map<String, String> welcomeMessages = {
    'ru': 'Вы запустили виртуального ассистента КозАлма. '
        'Для навигации используйте одно нажатие для озвучки кнопки, '
        'и двойное нажатие для активации.',
    'kz': 'Сіз КозАлма виртуалды көмекшісін іске қостыңыз. '
        'Навигация үшін бір рет басу — батырманы айту, '
        'екі рет басу — іске қосу.',
  };

  /// Language names for TTS.
  static const Map<String, String> languageNames = {
    'ru': 'Русский',
    'kz': 'Қазақша',
  };

  /// Speed change hint.
  static const Map<String, String> speedHint = {
    'ru': 'Для изменения скорости нажмите дважды слева или справа.',
    'kz': 'Жылдамдықты өзгерту үшін сол немесе оң жағын екі рет басыңыз.',
  };
}
