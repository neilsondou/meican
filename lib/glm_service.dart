import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'ai_keys.dart';
import 'app_config.dart';
import 'models.dart';

class GlmResult {
  const GlmResult({required this.items, required this.reply});

  final List<MealItem> items;
  final String reply;
}

class WeightScanRecord {
  const WeightScanRecord({required this.date, required this.value});

  final DateTime date;

  /// 图片中显示的原始数值，单位由 [WeightScanResult.unit] 决定。
  final double value;
}

class WeightScanResult {
  const WeightScanResult({
    required this.unit,
    required this.records,
    required this.reply,
    this.skipped = 0,
  });

  /// 为空表示截图里的单位不明确，需要让用户选择。
  final WeightUnit? unit;
  final List<WeightScanRecord> records;
  final String reply;
  final int skipped;
}

class GlmException implements Exception {
  const GlmException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GlmService {
  static final Uri _endpoint = Uri.parse(
    'https://open.bigmodel.cn/api/paas/v4/chat/completions',
  );

  static const Duration _timeout = Duration(seconds: 60);
  static const String _model = 'glm-4v-flash';

  static const String _mealSystemPrompt = '''
你是“每餐”的食物热量估算助手。根据照片和用户补充，估算实际吃掉的每种食物的可食部重量与总热量。
只输出一个合法 JSON 对象，不要输出 Markdown 代码围栏或任何额外文字：
{"items":[{"name":"米饭","grams":150,"kcal":174}],"reply":"..."}

估算规则：
1. 找出画面中所有食物和饮品，包括主食、配菜、汤、酱料和饮料。不要漏掉油、糖、坚果、芝士、沙拉酱等高热量配料；不可见的烹饪油和糖计入对应菜品，不必单列。
2. 用碗、盘子、餐具、手掌或包装等可见参照物估算分量。中式一小碗熟米饭约 130–180 克；一份家常菜约 150–250 克；一块手掌大的肉约 100–150 克。除非有证据，不要假设整份都吃完了。
3. grams 只算可食部，骨头、壳、核、包装不计入。kcal 是当前 grams 下实际摄入的总热量，不是每 100 克热量。
4. 必须结合做法：水煮、清蒸偏低；煎炒、红烧、油炸明显偏高。参考常见中国食物热量数据估算，热量取整数。
5. 光线、遮挡或参照物不足时，取合理区间的中间值，不要编造看不见的食物。没有可辨认食物时 items 返回 []。
6. 用户提出异议或补充时，以用户的描述为事实逐项重算；用户说的实际分量优先于照片观感。除非用户要求，否则不要新增照片之外的食物。
7. 合并同名同做法的食物，名称保持简短。reply 不超过 60 个汉字，直接说明估算依据和最不确定的一项，不要使用“作为 AI”等套话。
''';

  static const String _weightSystemPrompt = '''
你是“每餐”的体重记录转写助手。读取截图里所有体重记录，只输出一个合法 JSON 对象，不要输出 Markdown 代码围栏或任何额外文字：
{"unit":"kg","records":[{"date":"2026-10-25","weight":65.2}],"reply":"..."}

规则：
1. 只识别明确属于体重记录的日期和数值，忽略身高、BMI、目标体重、热量等无关数据。
2. date 必须尽量还原为 YYYY-MM-DD。根据截图里的年份、月份标题或上下文补全日期；如果只有月和日，使用不晚于今天的最近年份。无法确定具体日期的记录不要输出，绝不编造日期。
3. unit 只能填 kg、g 或 unknown。截图明确写 kg、公斤、千克时填 kg；明确写 g、克时填 g；没有任何单位时才填 unknown。不要仅凭数值大小猜单位。
4. weight 保留截图中的原始数值和单位，不要换算。相同日期出现多条时，只保留截图中最后或最完整的一条。
5. records 按日期从早到晚排列。reply 不超过 40 个汉字，说明识别依据；单位不明确时必须提醒。
''';

  Future<GlmResult> analyze({
    required Uint8List bytes,
    required String mimeType,
    String instruction = '',
    List<MealItem> currentItems = const [],
  }) async {
    final content = await _complete(
      bytes: bytes,
      mimeType: mimeType,
      systemPrompt: _mealSystemPrompt,
      userText: _mealRequestText(instruction, currentItems),
    );
    return _parseMealResult(content);
  }

  Future<WeightScanResult> recognizeWeights({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final content = await _complete(
      bytes: bytes,
      mimeType: mimeType,
      systemPrompt: _weightSystemPrompt,
      userText: '当前日期是 $date。请读取截图中的全部体重记录，严格按要求输出 JSON。',
    );
    return _parseWeightResult(content);
  }

  Future<String> _complete({
    required Uint8List bytes,
    required String mimeType,
    required String systemPrompt,
    required String userText,
  }) async {
    if (bytes.isEmpty) {
      throw const GlmException('图片为空，请重新选择图片。');
    }
    if (mimeType.trim().isEmpty) {
      throw const GlmException('无法确定图片格式，请重新选择图片。');
    }

    final requestBody = <String, dynamic>{
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userText},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${mimeType.trim()};base64,${base64Encode(bytes)}',
              },
            },
          ],
        },
      ],
    };

    if (kIsWeb) {
      final response = await _postProxy(requestBody);
      final status = response.statusCode;
      if (status >= 200 && status < 300) {
        return _extractContent(_responseText(response));
      }
      if (status == 429) {
        final detail = _errorDetail(_responseText(response));
        throw GlmException(detail.isEmpty ? '图片识别服务当前请求较多，请稍后重试。' : detail);
      }
      if (status == 413) {
        throw const GlmException('照片太大，请重新选择后再试。');
      }
      final detail = _errorDetail(_responseText(response));
      throw GlmException(
        '识别服务请求失败（HTTP $status）'
        '${detail.isEmpty ? '，请稍后重试。' : '：$detail'}',
      );
    }

    final keys = AiKeyPool.nextOrder();
    if (keys.isEmpty) {
      throw const GlmException('当前版本未启用图片识别服务，请安装配置后的版本。');
    }

    GlmException? retryable;
    for (final key in keys) {
      final response = await _post(key, requestBody);
      final status = response.statusCode;

      if (status >= 200 && status < 300) {
        return _extractContent(_responseText(response));
      }

      if (_canRetryWithAnotherKey(status)) {
        retryable = _statusException(status);
        continue;
      }

      final detail = _errorDetail(_responseText(response));
      throw GlmException(
        '识别服务请求失败（HTTP $status）'
        '${detail.isEmpty ? '，请稍后重试。' : '：$detail'}',
      );
    }

    throw retryable ?? const GlmException('图片识别服务暂时不可用，请稍后重试。');
  }

  static String _mealRequestText(
    String instruction,
    List<MealItem> currentItems,
  ) {
    final trimmed = instruction.trim();
    if (currentItems.isEmpty) {
      return trimmed.isEmpty ? '请识别照片中的全部食物，估算实际吃掉的克数与总热量。' : trimmed;
    }

    final current = jsonEncode(
      currentItems
          .map(
            (item) => {
              'name': item.name,
              'grams': item.grams,
              'kcal': item.kcal,
            },
          )
          .toList(),
    );
    return '用户对上一版估算的修正说明：'
        '${trimmed.isEmpty ? '用户认为估多了，请重新核对实际摄入量。' : trimmed}'
        '\n上一版清单：$current'
        '\n请按用户说明重新估算，返回修正后的完整 items。保留不受影响的项目，'
        '修改受影响的项目；除非用户要求，否则不要新增照片中不存在的食物。'
        'reply 直接说明这次调整了什么。';
  }

  Future<http.Response> _postProxy(Map<String, dynamic> requestBody) async {
    try {
      return await http
          .post(
            AppConfig.api('/api/ai/analyze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const GlmException('图片识别超时，请检查网络后重试。');
    } on http.ClientException {
      throw const GlmException('无法连接图片识别服务，请检查网络后重试。');
    } on Exception {
      throw const GlmException('图片识别请求失败，请稍后重试。');
    }
  }

  static String _responseText(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      return response.body;
    }
  }

  Future<http.Response> _post(
    String apiKey,
    Map<String, dynamic> requestBody,
  ) async {
    try {
      return await http
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const GlmException('图片识别超时，请检查网络后重试。');
    } on http.ClientException {
      if (kIsWeb) {
        throw const GlmException('网页预览受浏览器跨域限制，无法直接连接图片识别服务。请使用手机 App。');
      }
      throw const GlmException('无法连接图片识别服务，请检查网络后重试。');
    } on Exception {
      throw const GlmException('图片识别请求失败，请稍后重试。');
    }
  }

  static bool _canRetryWithAnotherKey(int status) {
    return status == 401 ||
        status == 403 ||
        status == 408 ||
        status == 429 ||
        status >= 500;
  }

  static GlmException _statusException(int status) {
    if (status == 401 || status == 403) {
      return const GlmException('图片识别服务配置已失效，请安装最新版本后重试。');
    }
    if (status == 429) {
      return const GlmException('图片识别服务当前请求较多，请稍后重试。');
    }
    return const GlmException('图片识别服务暂时不可用，请稍后重试。');
  }

  static String _extractContent(String body) {
    try {
      final root = _asMap(jsonDecode(body), '服务响应');
      if (root.containsKey('error')) {
        throw GlmException('识别服务返回错误：${_errorMessage(root['error'])}');
      }
      final choices = root['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const GlmException('识别服务没有返回结果，请重试。');
      }
      final choice = _asMap(choices.first, '识别结果');
      final message = _asMap(choice['message'], '识别结果');
      return _contentText(message['content']);
    } on GlmException {
      rethrow;
    } on FormatException {
      throw const GlmException('识别服务返回了无法解析的数据，请重试。');
    } catch (_) {
      throw const GlmException('识别结果格式不正确，请重试。');
    }
  }

  static GlmResult _parseMealResult(String content) {
    final root = _asMap(_decodeJsonContent(content), '识别结果');
    final rawItems = root['items'];
    if (rawItems is! List) {
      throw const GlmException('识别结果缺少 items 字段，请重试。');
    }
    final reply = root['reply'] is String
        ? (root['reply'] as String).trim()
        : '';

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final items = <MealItem>[];
    for (var index = 0; index < rawItems.length; index++) {
      final item = _asMap(rawItems[index], '食物');
      final name = item['name'] is String
          ? (item['name'] as String).trim()
          : '';
      final grams = _toDouble(item['grams'] ?? item['weight']);
      final kcal = _toDouble(item['kcal'] ?? item['calories']);
      if (name.isEmpty) {
        throw const GlmException('识别结果中的食物名称无效，请重试。');
      }
      if (grams == null ||
          !grams.isFinite ||
          grams < 0 ||
          kcal == null ||
          !kcal.isFinite ||
          kcal < 0) {
        throw const GlmException('识别结果中的克数或热量无效，请重试。');
      }
      items.add(
        MealItem(
          id: 'ai_${timestamp}_$index',
          name: name,
          grams: grams,
          kcal: kcal,
        ),
      );
    }
    return GlmResult(items: items, reply: reply);
  }

  static WeightScanResult _parseWeightResult(String content) {
    final root = _asMap(_decodeJsonContent(content), '识别结果');
    final rawRecords = root['records'] ?? root['items'];
    if (rawRecords is! List) {
      throw const GlmException('识别结果缺少 records 字段，请重试。');
    }

    final rawUnit = root['unit'];
    final unitText = rawUnit is String ? rawUnit.trim().toLowerCase() : '';
    final WeightUnit? unit =
        unitText == 'kg' || unitText == '公斤' || unitText == '千克'
        ? WeightUnit.kilograms
        : unitText == 'g' || unitText == '克'
        ? WeightUnit.grams
        : null;
    final reply = root['reply'] is String
        ? (root['reply'] as String).trim()
        : '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final records = <String, WeightScanRecord>{};
    var skipped = 0;
    for (final raw in rawRecords) {
      if (raw is! Map) {
        skipped++;
        continue;
      }
      final item = Map<String, dynamic>.from(raw);
      final date = _parseWeightDate(item['date']);
      final value = _toDouble(
        item['weight'] ?? item['value'] ?? item['kg'] ?? item['g'],
      );
      if (date == null ||
          date.isAfter(today) ||
          date.year < 2000 ||
          value == null ||
          !value.isFinite ||
          value <= 0) {
        skipped++;
        continue;
      }
      final key =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      records[key] = WeightScanRecord(date: date, value: value);
    }

    final sorted = records.values.toList()
      ..sort((first, second) => first.date.compareTo(second.date));
    return WeightScanResult(
      unit: unit,
      records: sorted,
      reply: reply,
      skipped: skipped,
    );
  }

  static DateTime? _parseWeightDate(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    if (text.isEmpty) return null;

    final direct = DateTime.tryParse(text);
    if (direct != null) {
      return DateTime(direct.year, direct.month, direct.day, 12);
    }

    final match = RegExp(
      r'(\d{4})\s*[-/.年]\s*(\d{1,2})\s*[-/.月]\s*(\d{1,2})',
    ).firstMatch(text);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day, 12);
    if (date.month != month || date.day != day) return null;
    return date;
  }

  static Object? _decodeJsonContent(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const GlmException('识别结果为空，请重试。');
    }

    var candidate = trimmed;
    final fence = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      caseSensitive: false,
    ).firstMatch(candidate);
    if (fence != null) candidate = fence.group(1)!.trim();

    try {
      return jsonDecode(candidate);
    } on FormatException {
      final start = candidate.indexOf('{');
      final end = candidate.lastIndexOf('}');
      if (start < 0 || end <= start) {
        throw const GlmException('识别结果不是有效的 JSON，请重试。');
      }
      try {
        return jsonDecode(candidate.substring(start, end + 1));
      } on FormatException {
        throw const GlmException('识别结果不是有效的 JSON，请重试。');
      }
    }
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.\-]'), ''));
    }
    return null;
  }

  static Map<String, dynamic> _asMap(Object? value, String label) {
    if (value is! Map) throw FormatException('$label 不是对象');
    return Map<String, dynamic>.from(value);
  }

  static String _contentText(Object? content) {
    if (content is String) return content;
    if (content is List) {
      return content
          .whereType<Map>()
          .map((part) => part['text'])
          .whereType<String>()
          .join('\n');
    }
    throw const GlmException('识别服务返回的内容格式不正确，请重试。');
  }

  static String _errorDetail(String body) {
    try {
      final root = jsonDecode(body);
      if (root is Map && root.containsKey('error')) {
        return _errorMessage(root['error']);
      }
      if (root is Map && root['message'] is String) {
        return root['message'] as String;
      }
    } on FormatException {
      // HTTP 状态码已足以说明失败，无需展示非 JSON 响应体。
    }
    return '';
  }

  static String _errorMessage(Object? error) {
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    if (error is String && error.isNotEmpty) return error;
    return '未知错误，请稍后重试。';
  }
}
