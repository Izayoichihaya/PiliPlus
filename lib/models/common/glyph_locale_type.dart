import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:PiliPlus/utils/chinese_converter.dart';
import 'package:get/get.dart';

/// 决定 App 的语言区域（Locale）。
///
/// 繁体（Hant）时：
/// 1. 由 [ChineseConverter] 把屏幕上显示的文字简转繁（界面、标题、评论、弹幕）；
/// 2. Flutter 会以 `Localizations.localeOf(context)` 为文字 locale，
///    Android 依此选用台湾 / 香港字形，而不是写死 zh_CN 时的大陆字形。
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

  /// 先载入/切换简繁转换，再更新 App 语言（触发全部文字重新排版）。
  static Future<void> switchTo(Locale locale) async {
    await ChineseConverter.apply(locale);
    await Get.updateLocale(locale);
  }

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
