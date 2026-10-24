import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';

class GlmResult {
  const GlmResult({required this.items, required this.reply});

  final List<MealItem> items;
  final String reply;
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

  Future<GlmResult> analyze({
    required String apiKey,
    required Uint8List bytes,
    required String mimeType,
    String instruction = '',
    List<MealItem> currentItems = const [],
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const GlmException('请先填写 API Key。');
    }
    if (bytes.isEmpty) {
      throw const GlmException('图片为空，请重新选择图片。');
    }
    if (mimeType.trim().isEmpty) {
      throw const GlmException('无法确定图片格式，请重新选择图片。');
    }

    final requestText = StringBuffer(
      instruction.trim().isEmpty ? '请识别图片中的食物并估算热量。' : instruction.trim(),
    );
    if (currentItems.isNotEmpty) {
      requestText
        ..write('\n当前食物列表为：')
        ..write(
          jsonEncode(
            currentItems
                .map(
                  (item) => {
                    'name': item.name,
                    'grams': item.grams,
                    'kcal': item.kcal,
                  },
                )
                .toList(),
          ),
        )
        ..write(
          '\n这是一次列表微调。请结合图片和要求修改，并返回覆盖当前列表的完整 items，'
          '不要只返回新增或变化的项。',
        );
    }

    final dataUrl = 'data:${mimeType.trim()};base64,${base64Encode(bytes)}';
    final requestBody = <String, dynamic>{
      'model': 'glm-4v-flash',
      'messages': [
        {
          'role': 'system',
          'content':
              '你是中文应用“每餐”的食物图像识别助手。只输出一个合法 JSON 对象，'
              '不要输出 Markdown 代码围栏或任何其他文本。格式必须为 '
              '{"items":[{"name":"米饭","grams":150,"kcal":174}],"reply":"..."}。'
              'items 中每种食物都必须有名称、估算克数 grams 和热量 kcal。'
              'kcal 必须是该食物在当前估算 grams 下的总热量，绝不能填每100克热量。'
              '尽量给出合理克数，热量只作估算。reply 用简短中文说明结果或不确定性。',
        },
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': requestText.toString()},
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl},
            },
          ],
        },
      ],
    };

    late final http.Response response;
    try {
      response = await http
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const GlmException('图片识别超时，请检查网络后重试。');
    } on http.ClientException {
      if (kIsWeb) {
        throw const GlmException(
          '网页预览受浏览器跨域限制，无法直接连接 AI 识别。请使用手机或桌面 App 拍照识别。',
        );
      }
      throw const GlmException('无法连接图片识别服务，请检查网络后重试。');
    } on Exception {
      throw const GlmException('图片识别请求失败，请稍后重试。');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const GlmException('API Key 无效或没有访问权限，请检查后重试。');
      }
      final detail = _errorDetail(response.body);
      throw GlmException(
        '识别服务请求失败（HTTP ${response.statusCode}）'
        '${detail.isEmpty ? '，请稍后重试。' : '：$detail'}',
      );
    }

    try {
      final root = _asMap(jsonDecode(response.body), '服务响应');
      if (root.containsKey('error')) {
        throw GlmException('识别服务返回错误：${_errorMessage(root['error'])}');
      }
      final choices = root['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const GlmException('识别服务没有返回结果，请重试。');
      }
      final choice = _asMap(choices.first, '识别结果');
      final message = _asMap(choice['message'], '识别结果');
      final content = _contentText(message['content']);
      return _parseResult(content);
    } on GlmException {
      rethrow;
    } on FormatException {
      throw const GlmException('识别服务返回了无法解析的数据，请重试。');
    } catch (_) {
      throw const GlmException('识别结果格式不正确，请重试。');
    }
  }

  GlmResult _parseResult(String content) {
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

    Object? decoded;
    try {
      decoded = jsonDecode(candidate);
    } on FormatException {
      final start = candidate.indexOf('{');
      final end = candidate.lastIndexOf('}');
      if (start < 0 || end <= start) {
        throw const GlmException('识别结果不是有效的 JSON，请重试。');
      }
      try {
        decoded = jsonDecode(candidate.substring(start, end + 1));
      } on FormatException {
        throw const GlmException('识别结果不是有效的 JSON，请重试。');
      }
    }

    final root = _asMap(decoded, '识别结果');
    final rawItems = root['items'];
    final reply = root['reply'];
    if (rawItems is! List || reply is! String) {
      throw const GlmException('识别结果缺少 items 或 reply 字段，请重试。');
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final items = <MealItem>[];
    for (var index = 0; index < rawItems.length; index++) {
      final item = _asMap(rawItems[index], '食物');
      final name = item['name'];
      final grams = item['grams'];
      final kcal = item['kcal'];
      if (name is! String || name.trim().isEmpty) {
        throw const GlmException('识别结果中的食物名称无效，请重试。');
      }
      if (grams is! num ||
          !grams.isFinite ||
          grams < 0 ||
          kcal is! num ||
          !kcal.isFinite ||
          kcal < 0) {
        throw const GlmException('识别结果中的克数或热量无效，请重试。');
      }
      items.add(
        MealItem(
          id: 'glm_${timestamp}_$index',
          name: name.trim(),
          grams: grams.toDouble(),
          kcal: kcal.toDouble(),
        ),
      );
    }
    return GlmResult(items: items, reply: reply.trim());
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
      // HTTP 状态码已足以向用户说明失败，无需显示非 JSON 响应体。
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
