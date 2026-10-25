import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'app_state.dart';
import 'sync_merge.dart';

class CloudLog {
  const CloudLog({
    required this.time,
    required this.message,
    this.error = false,
  });

  final DateTime time;
  final String message;
  final bool error;

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'message': message,
    'error': error,
  };

  factory CloudLog.fromJson(Map<String, dynamic> json) {
    return CloudLog(
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      message: json['message'] as String? ?? '',
      error: json['error'] as bool? ?? false,
    );
  }
}

class CloudSyncException implements Exception {
  const CloudSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _AuthException extends CloudSyncException {
  const _AuthException(super.message);
}

class _RemoteSnapshot {
  const _RemoteSnapshot({required this.revision, required this.data});

  final int revision;
  final SyncSnapshot? data;
}

class CloudSync extends ChangeNotifier {
  CloudSync(this.state);

  final AppState state;

  static const String _metaKey = 'meican_cloud_v1';
  static const String _logsKey = 'meican_cloud_logs_v1';
  static const Duration _debounce = Duration(milliseconds: 1200);
  static const Duration _requestTimeout = Duration(seconds: 25);

  String? _token;
  String? _username;
  DateTime? _lastSyncAt;
  int _revision = 0;
  bool _initialized = false;
  bool _busy = false;
  bool _syncing = false;
  bool _pending = false;
  int _seenMutation = 0;
  Timer? _uploadTimer;
  final List<CloudLog> _logs = [];

  bool get initialized => _initialized;
  bool get isLoggedIn => _token != null;
  String? get token => _token;
  String? get username => _username;
  DateTime? get lastSyncAt => _lastSyncAt;
  int get revision => _revision;
  bool get busy => _busy;
  bool get syncing => _syncing;
  List<CloudLog> get logs => List.unmodifiable(_logs);

  Future<void> init() async {
    if (_initialized) return;
    final SharedPreferences preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      _initialized = true;
      notifyListeners();
      return;
    }
    final rawMeta = preferences.getString(_metaKey);
    if (rawMeta != null && rawMeta.isNotEmpty) {
      try {
        final data = Map<String, dynamic>.from(
          jsonDecode(rawMeta) as Map<dynamic, dynamic>,
        );
        _token = data['token'] as String?;
        _username = data['username'] as String?;
        _lastSyncAt = DateTime.tryParse(data['lastSyncAt'] as String? ?? '');
      } catch (_) {
        // 本地会话损坏时回到未登录状态即可。
      }
    }

    final rawLogs = preferences.getString(_logsKey);
    if (rawLogs != null && rawLogs.isNotEmpty) {
      try {
        final list = jsonDecode(rawLogs) as List<dynamic>;
        _logs
          ..clear()
          ..addAll(
            list.whereType<Map>().map(
              (item) => CloudLog.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
      } catch (_) {
        // 日志只是辅助信息，读取失败不影响同步。
      }
    }

    _seenMutation = state.mutationVersion;
    state.addListener(_onStateChanged);
    _initialized = true;
    notifyListeners();
  }

  Future<void> syncOnLaunch() async {
    if (!isLoggedIn) return;
    await syncNow(manual: false);
  }

  Future<void> login(String username, String password) async {
    if (_busy) return;
    final name = username.trim();
    if (name.isEmpty || password.isEmpty) {
      throw const CloudSyncException('请输入账号和密码。');
    }
    _busy = true;
    notifyListeners();
    _log('正在登录…');
    try {
      final response = await _send(
        () => http.post(
          AppConfig.api('/api/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'username': name, 'password': password}),
        ),
      );
      if (response.statusCode == 401) {
        throw const CloudSyncException('账号或密码不正确。');
      }
      if (response.statusCode == 429) {
        throw const CloudSyncException('尝试次数过多，请稍后再试。');
      }
      if (response.statusCode != 200) {
        throw CloudSyncException(
          _serverError(response, '登录失败（HTTP ${response.statusCode}）。'),
        );
      }
      final data = _decodeObject(response);
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const CloudSyncException('登录响应缺少凭证，请稍后重试。');
      }
      _token = token;
      _username = data['username'] as String? ?? name;
      _lastSyncAt = null;
      _revision = 0;
      await _saveMeta();
      _log('登录成功，开始同步。');
      notifyListeners();
      await syncNow(manual: true);
    } catch (error) {
      final exception = error is CloudSyncException
          ? error
          : const CloudSyncException('登录失败，请稍后重试。');
      _log(exception.message, error: true);
      throw exception;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final token = _token;
    _uploadTimer?.cancel();
    _token = null;
    _username = null;
    _lastSyncAt = null;
    _revision = 0;
    _busy = false;
    _pending = false;
    await _saveMeta();
    if (token != null) {
      try {
        await _send(
          () => http.post(
            AppConfig.api('/api/logout'),
            headers: {'Authorization': 'Bearer $token'},
          ),
          timeout: const Duration(seconds: 8),
        );
      } catch (_) {
        // 退出登录优先清理本机会话，服务端不可达时不阻塞。
      }
    }
    _log('已退出云同步，本机数据仍然保留。');
    notifyListeners();
  }

  Future<void> syncNow({bool manual = false}) async {
    if (!isLoggedIn) return;
    if (_syncing) {
      _pending = true;
      return;
    }
    _syncing = true;
    _busy = true;
    notifyListeners();
    try {
      await _runSync(manual: manual);
    } catch (_) {
      _log('同步失败，请稍后重试。', error: true);
    } finally {
      _syncing = false;
      _busy = false;
      notifyListeners();
      if (_pending) {
        _pending = false;
        unawaited(Future<void>.delayed(Duration.zero, () => syncNow()));
      }
    }
  }

  Future<void> _runSync({required bool manual}) async {
    if (manual) _log('正在与云端同步…');
    var attempts = 0;
    while (attempts < 3) {
      attempts++;
      final localVersion = state.mutationVersion;
      try {
        final remote = await _fetchSync();
        // 拉取期间用户又改了本机数据时，重新合并，避免用旧快照覆盖新记录。
        if (state.mutationVersion != localVersion) continue;
        final local = state.toSyncSnapshot();
        final merge = mergeSyncSnapshots(local, remote.data);

        if (merge.localChanged) {
          await state.applySyncSnapshot(merge.snapshot);
          _seenMutation = state.mutationVersion;
          _log(_mergeMessage(merge.snapshot));
        }

        if (!merge.remoteChanged && remote.data != null) {
          _revision = remote.revision;
          _lastSyncAt = DateTime.now();
          await _saveMeta();
          if (manual) _log('已是最新（云端版本 ${remote.revision}）。');
          return;
        }

        final result = await _putSync(remote.revision, merge.snapshot);
        if (result == null) continue;

        _revision = result;
        _lastSyncAt = DateTime.now();
        await _saveMeta();
        _log(manual ? '同步完成，已上传（版本 $result）。' : '后台已上传（版本 $result）。');
        return;
      } on _AuthException catch (error) {
        _token = null;
        _username = null;
        _lastSyncAt = null;
        _revision = 0;
        await _saveMeta();
        _log(error.message, error: true);
        return;
      } on CloudSyncException catch (error) {
        _log(error.message, error: true);
        return;
      }
    }
    _log('云端数据更新频繁，暂时无法合并，请稍后重试。', error: true);
  }

  Future<_RemoteSnapshot> _fetchSync() async {
    final response = await _send(
      () => http.get(
        AppConfig.api('/api/sync'),
        headers: {'Authorization': 'Bearer $_token'},
      ),
    );
    _ensureAuthorized(response);
    if (response.statusCode != 200) {
      throw CloudSyncException(
        _serverError(response, '读取云端数据失败（HTTP ${response.statusCode}）。'),
      );
    }
    final data = _decodeObject(response);
    final revision = (data['revision'] as num?)?.toInt() ?? 0;
    final rawData = data['data'];
    if (rawData == null) {
      return _RemoteSnapshot(revision: revision, data: null);
    }
    if (rawData is! Map) {
      throw const CloudSyncException('云端数据格式异常，已保留本机数据。');
    }
    try {
      return _RemoteSnapshot(
        revision: revision,
        data: SyncSnapshot.fromJson(Map<String, dynamic>.from(rawData)),
      );
    } catch (_) {
      throw const CloudSyncException('云端数据无法解析，已保留本机数据。');
    }
  }

  Future<int?> _putSync(int baseRevision, SyncSnapshot snapshot) async {
    final response = await _send(
      () => http.put(
        AppConfig.api('/api/sync'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'baseRevision': baseRevision,
          'data': snapshot.toJson(),
        }),
      ),
    );
    _ensureAuthorized(response);
    if (response.statusCode == 409) return null;
    if (response.statusCode == 413) {
      throw const CloudSyncException('本机数据体积过大，无法上传。');
    }
    if (response.statusCode != 200) {
      throw CloudSyncException(
        _serverError(response, '上传失败（HTTP ${response.statusCode}）。'),
      );
    }
    final data = _decodeObject(response);
    return (data['revision'] as num?)?.toInt();
  }

  void _ensureAuthorized(http.Response response) {
    if (response.statusCode == 401) {
      throw const _AuthException('登录已过期，请在云同步中重新登录。');
    }
  }

  void _onStateChanged() {
    if (!_initialized) return;
    if (state.mutationVersion <= _seenMutation) return;
    _seenMutation = state.mutationVersion;
    if (!isLoggedIn) return;
    _uploadTimer?.cancel();
    _uploadTimer = Timer(_debounce, () {
      if (isLoggedIn) unawaited(syncNow());
    });
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    Duration timeout = _requestTimeout,
  }) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const CloudSyncException('连接云端超时，请检查网络后重试。');
    } on http.ClientException {
      throw const CloudSyncException('连接不到同步服务器，请检查网络。');
    } catch (error) {
      if (error is CloudSyncException) rethrow;
      throw const CloudSyncException('网络请求失败，请稍后重试。');
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // 统一走下方错误提示。
    }
    throw const CloudSyncException('云端返回了无法解析的数据。');
  }

  String _serverError(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // 使用调用方提供的提示。
    }
    return fallback;
  }

  String _mergeMessage(SyncSnapshot snapshot) {
    return '已合并云端更新：${snapshot.meals.length} 餐 · '
        '${snapshot.weights.length} 条体重。';
  }

  Future<void> _saveMeta() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _metaKey,
        jsonEncode({
          'token': _token,
          'username': _username,
          'lastSyncAt': _lastSyncAt?.toIso8601String(),
        }),
      );
    } catch (_) {
      // 会话持久化失败时仍保留内存中的登录状态。
    }
  }

  void _log(String message, {bool error = false}) {
    _logs.add(CloudLog(time: DateTime.now(), message: message, error: error));
    if (_logs.length > 40) _logs.removeRange(0, _logs.length - 40);
    unawaited(_saveLogs());
    notifyListeners();
  }

  Future<void> _saveLogs() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _logsKey,
        jsonEncode(_logs.map((log) => log.toJson()).toList()),
      );
    } catch (_) {
      // 日志写入失败不应影响同步。
    }
  }

  @override
  void dispose() {
    _uploadTimer?.cancel();
    state.removeListener(_onStateChanged);
    super.dispose();
  }
}
