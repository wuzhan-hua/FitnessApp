import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _defaultSourceVersion = String.fromEnvironment(
  'FREE_EXERCISE_DB_SOURCE_VERSION',
  defaultValue: 'main',
);

const _defaultBucketName = String.fromEnvironment(
  'SUPABASE_EXERCISE_BUCKET',
  defaultValue: 'exercise-reference',
);

final Map<String, String> _muscleTranslations = {
  'abdominals': '腹肌',
  'abductors': '髋外展肌',
  'adductors': '髋内收肌',
  'biceps': '肱二头肌',
  'calves': '小腿',
  'chest': '胸部',
  'forearms': '前臂',
  'glutes': '臀部',
  'hamstrings': '股二头肌',
  'lats': '背阔肌',
  'lower back': '下背',
  'lower_back': '下背',
  'middle back': '中背',
  'middle_back': '中背',
  'neck': '颈部',
  'quadriceps': '股四头肌',
  'shoulders': '肩部',
  'traps': '斜方肌',
  'triceps': '肱三头肌',
};

final Map<String, String> _equipmentTranslations = {
  'band': '弹力带',
  'bands': '弹力带',
  'barbell': '杠铃',
  'body only': '徒手',
  'cable': '绳索',
  'dumbbell': '哑铃',
  'exercise ball': '健身球',
  'e-z curl bar': 'EZ 弯举杠',
  'foam roll': '泡沫轴',
  'kettlebells': '壶铃',
  'machine': '器械',
  'medicine ball': '药球',
  'none': '无器械',
  'other': '其他',
};

final Map<String, String> _categoryTranslations = {
  'cardio': '有氧',
  'olympic weightlifting': '奥林匹克举重',
  'plyometrics': '增强式训练',
  'powerlifting': '力量举',
  'strength': '力量',
  'stretching': '拉伸',
  'strongman': '大力士训练',
};

Future<void> main(List<String> args) async {
  final config = _ImportConfig.fromEnvironment();
  final importer = _FreeExerciseDbImporter(config);
  await importer.run();
}

class _ImportConfig {
  const _ImportConfig({
    required this.supabaseUrl,
    required this.serviceRoleKey,
    required this.localRoot,
    required this.sourceVersion,
    required this.bucketName,
    required this.batchSize,
  });

  final String supabaseUrl;
  final String serviceRoleKey;
  final String localRoot;
  final String sourceVersion;
  final String bucketName;
  final int batchSize;

  String get restBaseUrl => '$supabaseUrl/rest/v1';
  String get storageBaseUrl => '$supabaseUrl/storage/v1';
  String get localJsonPath => '$localRoot/dist/exercises.json';
  String get localExercisesRoot => '$localRoot/exercises';

  factory _ImportConfig.fromEnvironment() {
    final supabaseUrl = Platform.environment['SUPABASE_URL']?.trim() ?? '';
    final serviceRoleKey =
        Platform.environment['SUPABASE_SERVICE_ROLE_KEY']?.trim() ?? '';
    final localRoot =
        Platform.environment['FREE_EXERCISE_DB_LOCAL_ROOT']?.trim() ?? '';
    final sourceVersion =
        Platform.environment['FREE_EXERCISE_DB_SOURCE_VERSION']?.trim() ??
        _defaultSourceVersion;
    final bucketName =
        Platform.environment['SUPABASE_EXERCISE_BUCKET']?.trim() ??
        _defaultBucketName;
    final batchSizeRaw =
        Platform.environment['FREE_EXERCISE_DB_BATCH_SIZE']?.trim() ?? '50';
    final batchSize = int.tryParse(batchSizeRaw) ?? 50;

    if (supabaseUrl.isEmpty || serviceRoleKey.isEmpty || localRoot.isEmpty) {
      stderr.writeln(
        '缺少 SUPABASE_URL、SUPABASE_SERVICE_ROLE_KEY 或 FREE_EXERCISE_DB_LOCAL_ROOT 环境变量。',
      );
      stderr.writeln(
        '示例：SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... '
        'FREE_EXERCISE_DB_LOCAL_ROOT=... dart run tool/import_free_exercise_db.dart',
      );
      exitCode = 64;
      throw StateError('缺少导入所需环境变量');
    }

    final normalizedLocalRoot = localRoot.replaceAll(RegExp(r'/$'), '');
    final rootDir = Directory(normalizedLocalRoot);
    final jsonFile = File('$normalizedLocalRoot/dist/exercises.json');
    final exercisesDir = Directory('$normalizedLocalRoot/exercises');
    if (!rootDir.existsSync() ||
        !jsonFile.existsSync() ||
        !exercisesDir.existsSync()) {
      stderr.writeln('本地 free-exercise-db 目录无效: $normalizedLocalRoot');
      stderr.writeln('需要存在 dist/exercises.json 和 exercises/ 目录。');
      exitCode = 64;
      throw StateError('本地 free-exercise-db 目录无效');
    }

    return _ImportConfig(
      supabaseUrl: supabaseUrl.replaceAll(RegExp(r'/$'), ''),
      serviceRoleKey: serviceRoleKey,
      localRoot: normalizedLocalRoot,
      sourceVersion: sourceVersion,
      bucketName: bucketName,
      batchSize: batchSize < 1 ? 1 : batchSize,
    );
  }
}

class _FreeExerciseDbImporter {
  _FreeExerciseDbImporter(this._config) : _client = HttpClient();

  final _ImportConfig _config;
  final HttpClient _client;
  final Set<String> _missingMuscleMappings = <String>{};
  final Set<String> _missingEquipmentMappings = <String>{};
  final Set<String> _missingCategoryMappings = <String>{};

  Future<void> run() async {
    stdout.writeln('开始导入 free-exercise-db...');
    stdout.writeln('本地仓库根目录: ${_config.localRoot}');
    stdout.writeln('JSON 文件: ${_config.localJsonPath}');
    stdout.writeln('图片目录: ${_config.localExercisesRoot}');
    stdout.writeln('数据源版本: ${_config.sourceVersion}');
    stdout.writeln('目标 Bucket: ${_config.bucketName}');

    final rawExercises = await _fetchExercises();
    final report = _ImportReport(totalExercises: rawExercises.length);
    final rows = <Map<String, dynamic>>[];

    for (final rawExercise in rawExercises) {
      try {
        final prepared = await _prepareExercise(rawExercise, report);
        rows.add(prepared);
      } catch (error) {
        report.failedExercises++;
        stderr.writeln(
          '处理动作失败: ${rawExercise['id'] ?? '<unknown>'} -> $error',
        );
      }
    }

    await _upsertInBatches(rows);
    report.successExercises = rows.length;

    _printReport(report);
    _client.close(force: true);
  }

  Future<List<Map<String, dynamic>>> _fetchExercises() async {
    final content = await File(_config.localJsonPath).readAsString();
    final response = jsonDecode(content);
    if (response is! List) {
      throw StateError('上游 exercises.json 结构不是数组');
    }
    return response.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _prepareExercise(
    Map<String, dynamic> raw,
    _ImportReport report,
  ) async {
    final id = (raw['id'] as String? ?? '').trim();
    final name = (raw['name'] as String? ?? '').trim();
    if (id.isEmpty || name.isEmpty) {
      throw StateError('动作缺少 id 或 name');
    }

    final primaryMusclesEn = _readStringList(raw['primaryMuscles']);
    final secondaryMusclesEn = _readStringList(raw['secondaryMuscles']);
    final instructionsEn = _readStringList(raw['instructions']);
    final imagePaths = _readStringList(raw['images']);
    final equipmentEn = _normalizeNullableText(raw['equipment']);
    final categoryEn = _normalizeNullableText(raw['category']);
    final forceEn = _normalizeNullableText(raw['force']);
    final mechanicEn = _normalizeNullableText(raw['mechanic']);
    final levelEn = _normalizeNullableText(raw['level']);

    if (equipmentEn == null) {
      report.missingEquipmentCount++;
    }

    final primaryMusclesZh = primaryMusclesEn
        .map(_translateMuscle)
        .whereType<String>()
        .toList();
    final secondaryMusclesZh = secondaryMusclesEn
        .map(_translateMuscle)
        .whereType<String>()
        .toList();
    final equipmentZh = equipmentEn == null ? null : _translateEquipment(equipmentEn);
    final categoryZh = categoryEn == null ? null : _translateCategory(categoryEn);

    final uploadedImagePaths = <String>[];
    for (var index = 0; index < imagePaths.length; index++) {
      final sourceRelativePath = imagePaths[index];
      final targetPath = '$id/$index.jpg';
      try {
        final bytes = await _readLocalImage(sourceRelativePath);
        await _uploadImage(
          path: targetPath,
          bytes: bytes,
          contentType: _guessContentType(sourceRelativePath),
        );
        uploadedImagePaths.add(targetPath);
      } catch (error) {
        report.failedImageCount++;
        stderr.writeln(
          '上传图片失败: $id -> '
          '${_config.localExercisesRoot}/$sourceRelativePath -> $error',
        );
      }
    }

    return {
      'id': id,
      'name_en': name,
      'name_zh': null,
      'equipment_en': equipmentEn,
      'equipment_zh': equipmentZh,
      'category_en': categoryEn,
      'category_zh': categoryZh,
      'force_en': forceEn,
      'mechanic_en': mechanicEn,
      'level_en': levelEn,
      'primary_muscles_en': primaryMusclesEn,
      'primary_muscles_zh': primaryMusclesZh,
      'secondary_muscles_en': secondaryMusclesEn,
      'secondary_muscles_zh': secondaryMusclesZh,
      'instructions_en': instructionsEn,
      'instructions_zh': const <String>[],
      'image_paths': uploadedImagePaths,
      'cover_image_path': uploadedImagePaths.isEmpty ? null : uploadedImagePaths.first,
      'source': 'free-exercise-db',
      'source_version': _config.sourceVersion,
      'is_active': true,
    };
  }

  Future<Uint8List> _readLocalImage(String relativePath) async {
    final normalized = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    final file = File('${_config.localExercisesRoot}/$normalized');
    if (!file.existsSync()) {
      throw FileSystemException('本地图片不存在', file.path);
    }
    return file.readAsBytes();
  }

  Future<void> _uploadImage({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final encodedBucket = Uri.encodeComponent(_config.bucketName);
    final encodedObjectPath = _encodeObjectPath(path);
    final uploadUrl = Uri.parse(
      '${_config.storageBaseUrl}/object/$encodedBucket/$encodedObjectPath',
    );
    final request = await _client.postUrl(
      uploadUrl,
    );
    _addSupabaseAuthHeaders(request);
    request.headers.set(HttpHeaders.contentTypeHeader, contentType);
    request.headers.set('x-upsert', 'true');
    request.add(bytes);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Storage 上传失败: ${response.statusCode} $body '
        '(bucket=${_config.bucketName}, key=$path, url=$uploadUrl)',
        uri: uploadUrl,
      );
    }
  }

  Future<void> _upsertInBatches(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      stdout.writeln('没有可导入动作，跳过 upsert。');
      return;
    }
    for (var i = 0; i < rows.length; i += _config.batchSize) {
      final end = (i + _config.batchSize < rows.length)
          ? i + _config.batchSize
          : rows.length;
      final batch = rows.sublist(i, end);
      final request = await _client.postUrl(
        Uri.parse(
          '${_config.restBaseUrl}/exercise_catalog_items?on_conflict=id',
        ),
      );
      _addSupabaseAuthHeaders(request);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('Prefer', 'resolution=merge-duplicates,return=minimal');
      final payload = utf8.encode(jsonEncode(batch));
      request.headers.contentLength = payload.length;
      request.add(payload);
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final firstId = batch.isEmpty ? '<empty>' : '${batch.first['id']}';
        throw HttpException(
          '目录 upsert 失败: ${response.statusCode} $body '
          '(batch=${i + 1}-$end, first_id=$firstId)',
          uri: Uri.parse(
            '${_config.restBaseUrl}/exercise_catalog_items?on_conflict=id',
          ),
        );
      }
      stdout.writeln('已写入 $end/${rows.length} 条动作目录');
    }
  }

  void _addSupabaseAuthHeaders(HttpClientRequest request) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${_config.serviceRoleKey}');
    request.headers.set('apikey', _config.serviceRoleKey);
  }

  String? _translateMuscle(String value) {
    final normalized = value.trim();
    final translated = _muscleTranslations[normalized];
    if (translated == null) {
      _missingMuscleMappings.add(normalized);
    }
    return translated;
  }

  String? _translateEquipment(String value) {
    final normalized = value.trim().toLowerCase();
    final translated = _equipmentTranslations[normalized];
    if (translated == null) {
      _missingEquipmentMappings.add(normalized);
    }
    return translated;
  }

  String? _translateCategory(String value) {
    final normalized = value.trim().toLowerCase();
    final translated = _categoryTranslations[normalized];
    if (translated == null) {
      _missingCategoryMappings.add(normalized);
    }
    return translated;
  }

  void _printReport(_ImportReport report) {
    stdout.writeln('');
    stdout.writeln('导入完成');
    stdout.writeln('总动作数: ${report.totalExercises}');
    stdout.writeln('成功入库数: ${report.successExercises}');
    stdout.writeln('处理失败动作数: ${report.failedExercises}');
    stdout.writeln('缺失器械字段数: ${report.missingEquipmentCount}');
    stdout.writeln('图片下载/上传失败数: ${report.failedImageCount}');
    stdout.writeln('缺失肌群中文映射: ${_formatMissingItems(_missingMuscleMappings)}');
    stdout.writeln('缺失器械中文映射: ${_formatMissingItems(_missingEquipmentMappings)}');
    stdout.writeln('缺失分类中文映射: ${_formatMissingItems(_missingCategoryMappings)}');
  }

  String _formatMissingItems(Set<String> items) {
    if (items.isEmpty) {
      return '无';
    }
    final sorted = items.toList()..sort();
    return sorted.join(', ');
  }

  String _encodeObjectPath(String path) {
    return path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
  }
}

class _ImportReport {
  _ImportReport({required this.totalExercises});

  final int totalExercises;
  int successExercises = 0;
  int failedExercises = 0;
  int missingEquipmentCount = 0;
  int failedImageCount = 0;
}

List<String> _readStringList(dynamic raw) {
  if (raw is! List) {
    return const [];
  }
  return raw
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

String? _normalizeNullableText(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

String _guessContentType(String path) {
  final normalized = path.toLowerCase();
  if (normalized.endsWith('.png')) {
    return 'image/png';
  }
  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
