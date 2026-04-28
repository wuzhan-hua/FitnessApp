import 'dart:convert';
import 'dart:io';

const _defaultZhJsonPath = 'tool/free-exercise-db-zh.json';

Future<void> main() async {
  final config = _UpdateConfig.fromEnvironment();
  final updater = _ExerciseZhSyncer(config);
  await updater.run();
}

class _UpdateConfig {
  const _UpdateConfig({
    required this.supabaseUrl,
    required this.serviceRoleKey,
    required this.zhJsonPath,
  });

  final String supabaseUrl;
  final String serviceRoleKey;
  final String zhJsonPath;

  String get restBaseUrl => '$supabaseUrl/rest/v1';

  factory _UpdateConfig.fromEnvironment() {
    final supabaseUrl = Platform.environment['SUPABASE_URL']?.trim() ?? '';
    final serviceRoleKey =
        Platform.environment['SUPABASE_SERVICE_ROLE_KEY']?.trim() ?? '';
    final zhJsonPath =
        Platform.environment['FREE_EXERCISE_ZH_JSON_PATH']?.trim() ??
        Platform.environment['FREE_EXERCISE_NAME_ZH_SOURCE']?.trim() ??
        _defaultZhJsonPath;
    if (supabaseUrl.isEmpty || serviceRoleKey.isEmpty || zhJsonPath.isEmpty) {
      stderr.writeln(
        '缺少 SUPABASE_URL、SUPABASE_SERVICE_ROLE_KEY 或 FREE_EXERCISE_ZH_JSON_PATH 环境变量。',
      );
      exitCode = 64;
      throw StateError('缺少中文同步脚本所需环境变量');
    }
    final file = File(zhJsonPath);
    if (!file.existsSync()) {
      stderr.writeln('中文数据文件不存在: $zhJsonPath');
      exitCode = 64;
      throw StateError('中文数据文件不存在');
    }
    return _UpdateConfig(
      supabaseUrl: supabaseUrl.replaceAll(RegExp(r'/$'), ''),
      serviceRoleKey: serviceRoleKey,
      zhJsonPath: zhJsonPath,
    );
  }
}

class _ExerciseZhSyncer {
  _ExerciseZhSyncer(this._config) : _client = HttpClient();

  final _UpdateConfig _config;
  final HttpClient _client;

  Future<void> run() async {
    stdout.writeln('开始同步中文动作名与说明...');
    stdout.writeln('中文数据文件: ${_config.zhJsonPath}');

    final catalogRows = await _fetchCatalogRows();
    final zhRows = await _readZhRows();
    final zhById = <String, Map<String, dynamic>>{
      for (final row in zhRows) row.id: row.toJson(),
    };

    var updatedCount = 0;
    var skippedCount = 0;
    final missingIds = <String>[];

    for (final row in catalogRows) {
      final id = '${row['id'] ?? ''}'.trim();
      if (id.isEmpty) {
        continue;
      }
      final zhRow = zhById[id];
      if (zhRow == null) {
        missingIds.add(id);
        continue;
      }

      final payload = <String, dynamic>{};
      final nameZh = '${zhRow['name_zh'] ?? ''}'.trim();
      final instructionsZh = _normalizeInstructions(zhRow['instructions_zh']);
      if (nameZh.isNotEmpty) {
        payload['name_zh'] = nameZh;
      }
      if (instructionsZh.isNotEmpty) {
        payload['instructions_zh'] = instructionsZh;
      }
      if (payload.isEmpty) {
        skippedCount++;
        continue;
      }
      await _updateCatalogRow(id: id, payload: payload);
      updatedCount++;
    }

    stdout.writeln('同步完成');
    stdout.writeln('目录记录数: ${catalogRows.length}');
    stdout.writeln('中文文件记录数: ${zhRows.length}');
    stdout.writeln('成功更新数: $updatedCount');
    stdout.writeln('跳过更新数: $skippedCount');
    stdout.writeln('未命中 id 数: ${missingIds.length}');
    if (missingIds.isNotEmpty) {
      final preview = missingIds.take(20).join(', ');
      stdout.writeln('未命中 id 示例: $preview');
    }
    _client.close(force: true);
  }

  Future<List<Map<String, dynamic>>> _fetchCatalogRows() async {
    final request = await _client.getUrl(
      Uri.parse(
        '${_config.restBaseUrl}/exercise_catalog_items?select=id,name_en,name_zh,instructions_en,instructions_zh',
      ),
    );
    _addHeaders(request);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('读取动作目录失败: ${response.statusCode} $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw StateError('动作目录返回结构异常');
    }
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<List<_ZhExerciseRow>> _readZhRows() async {
    final file = File(_config.zhJsonPath);
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw StateError('中文数据文件顶层必须是数组');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_ZhExerciseRow.fromJson)
        .where((row) => row.id.isNotEmpty)
        .toList();
  }

  Future<void> _updateCatalogRow({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final request = await _client.patchUrl(
      Uri.parse(
        '${_config.restBaseUrl}/exercise_catalog_items?id=eq.${Uri.encodeQueryComponent(id)}',
      ),
    );
    _addHeaders(request);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set('Prefer', 'return=minimal');
    final encoded = utf8.encode(jsonEncode(payload));
    request.headers.contentLength = encoded.length;
    request.add(encoded);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('回写中文数据失败: ${response.statusCode} $body');
    }
  }

  void _addHeaders(HttpClientRequest request) {
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${_config.serviceRoleKey}',
    );
    request.headers.set('apikey', _config.serviceRoleKey);
  }

  List<String> _normalizeInstructions(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class _ZhExerciseRow {
  const _ZhExerciseRow({
    required this.id,
    required this.nameZh,
    required this.instructionsZh,
  });

  final String id;
  final String nameZh;
  final List<String> instructionsZh;

  factory _ZhExerciseRow.fromJson(Map<String, dynamic> json) {
    return _ZhExerciseRow(
      id: '${json['id'] ?? ''}'.trim(),
      nameZh: '${json['name'] ?? ''}'.trim(),
      instructionsZh: _readInstructions(json['instructions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_zh': nameZh,
      'instructions_zh': instructionsZh,
    };
  }

  static List<String> _readInstructions(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
