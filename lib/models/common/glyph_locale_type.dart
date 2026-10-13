import 'dart:ui' show Locale, PlatformDispatcher;

/// 决定 App 的语言区域（Locale）。
///
/// Flutter 的 Text / TextField 会以 `Localizations.localeOf(context)`
/// 作为文字的 locale，Android 再依此从系统字体中挑选同一汉字的
/// 地区字形（简体 / 繁體台灣 / 繁體香港）。原本 App 写死 zh_CN，
/// 所以繁体系统上的汉字也会显示成大陆字形；改为跟随系统即可与原版一致。
enum GlyphLocaleType {
  system('跟随系统'),
  hans('简体中文（中国大陆）'),
  hantTW('繁體中文（台灣）'),
  hantHK('繁體中文（香港）');

  final String label;
  const GlyphLocaleType(this.label);

  static const hansLocale = Locale('zh', 'CN');
  static const hantTWLocale = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
    countryCode: 'TW',
  );
  static const hantHKLocale = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
    countryCode: 'HK',
  );

  static const supportedLocales = [
    hansLocale,
    hantTWLocale,
    hantHKLocale,
    Locale('en', 'US'),
  ];

  Locale get locale => switch (this) {
    system => _fromSystem(),
    hans => hansLocale,
    hantTW => hantTWLocale,
    hantHK => hantHKLocale,
  };

  /// 取系统偏好语言列表中第一个中文语言；没有中文时维持简体。
  static Locale _fromSystem() {
    for (final l in PlatformDispatcher.instance.locales) {
      if (l.languageCode != 'zh') continue;
      if (l.scriptCode == 'Hans') return hansLocale;
      final country = l.countryCode?.toUpperCase();
      if (country == 'HK' || country == 'MO') return hantHKLocale;
      if (country == 'TW') return hantTWLocale;
      if (l.scriptCode == 'Hant') return hantTWLocale;
      return hansLocale;
    }
    return hansLocale;
  }
}
