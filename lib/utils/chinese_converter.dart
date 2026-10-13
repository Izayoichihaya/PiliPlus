import 'dart:math' show min;
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/painting.dart' show TextSpan;
import 'package:flutter/services.dart' show rootBundle;

/// 显示层的简体 -> 繁体转换（数据来自 OpenCC，见 assets/opencc/LICENSE）。
///
/// 通过 Flutter SDK 补丁（lib/scripts/text_span_transform.patch）挂在
/// [TextSpan.build] 上，只改变画到屏幕上的字，不改变任何数据本身，
/// 所以搜索、发送评论、接口请求等都不受影响。
///
/// 转换严格保持 UTF-16 长度不变（逐字或等长词组），
/// 光标、选取、点击位置因此不会错位。
abstract final class ChineseConverter {
  static Map<int, int>? _chars;
  static Map<String, String>? _phrases;

  /// 词组首字 -> 以该字开头的最长词组长度
  static Map<int, int>? _heads;
  static String? _region;

  static bool get isEnabled => TextSpan.textTransform != null;

  /// 给不经过 [TextSpan] 、直接用 ParagraphBuilder 画字的地方（例如弹幕）使用。
  static String display(String s) => isEnabled ? convert(s) : s;

  /// 依据 [locale] 开启或关闭转换：只有繁体（Hant）时开启。
  static Future<void> apply(Locale locale) async {
    if (locale.scriptCode != 'Hant') {
      TextSpan.textTransform = null;
      return;
    }
    final region = locale.countryCode == 'HK' ? 'hk' : 'tw';
    try {
      if (_region != region) await _load(region);
      TextSpan.textTransform = convert;
    } catch (e) {
      TextSpan.textTransform = null;
      if (kDebugMode) debugPrint('ChineseConverter load error: $e');
    }
  }

  static Iterable<(String, String)> _parse(String data) sync* {
    for (final line in data.split('\n')) {
      final i = line.indexOf('\t');
      if (i <= 0) continue;
      yield (line.substring(0, i), line.substring(i + 1).trimRight());
    }
  }

  static Future<void> _load(String region) async {
    final [chars, phrases, variants] = await Future.wait([
      rootBundle.loadString('assets/opencc/st_chars.txt'),
      rootBundle.loadString('assets/opencc/st_phrases.txt'),
      rootBundle.loadString('assets/opencc/${region}_variants.txt'),
    ]);

    final variantMap = <int, int>{
      for (final (k, v) in _parse(variants)) k.codeUnitAt(0): v.codeUnitAt(0),
    };
    int variant(int c) => variantMap[c] ?? c;

    final charMap = <int, int>{
      for (final (k, v) in _parse(chars)) k.codeUnitAt(0): variant(v.codeUnitAt(0)),
    };
    // 本身不需简转繁、但有地区异体的字
    for (final MapEntry(:key, :value) in variantMap.entries) {
      charMap.putIfAbsent(key, () => value);
    }

    final phraseMap = <String, String>{};
    final heads = <int, int>{};
    for (final (k, v) in _parse(phrases)) {
      if (k.length != v.length || k.length < 2) continue;
      phraseMap[k] = String.fromCharCodes(v.codeUnits.map(variant));
      final h = k.codeUnitAt(0);
      final len = heads[h];
      if (len == null || k.length > len) heads[h] = k.length;
    }

    _chars = charMap;
    _phrases = phraseMap;
    _heads = heads;
    _region = region;
  }

  /// 最长词组优先匹配，其余逐字转换；输出长度与输入相同。
  static String convert(String s) {
    final chars = _chars;
    if (chars == null || s.isEmpty) return s;
    final phrases = _phrases!;
    final heads = _heads!;

    List<int>? out;
    final n = s.length;
    var i = 0;
    while (i < n) {
      final c = s.codeUnitAt(i);
      // 0x3400 以下不含汉字（ASCII、标点、假名等），直接跳过
      if (c < 0x3400) {
        i++;
        continue;
      }
      final maxLen = heads[c];
      if (maxLen != null) {
        var matched = 0;
        for (var len = min(maxLen, n - i); len >= 2; len--) {
          final v = phrases[s.substring(i, i + len)];
          if (v != null) {
            out ??= s.codeUnits.toList(growable: false);
            for (var j = 0; j < len; j++) {
              out[i + j] = v.codeUnitAt(j);
            }
            matched = len;
            break;
          }
        }
        if (matched != 0) {
          i += matched;
          continue;
        }
      }
      final t = chars[c];
      if (t != null) {
        out ??= s.codeUnits.toList(growable: false);
        out[i] = t;
      }
      i++;
    }
    return out == null ? s : String.fromCharCodes(out);
  }
}
