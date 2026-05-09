import 'dart:convert';
import 'dart:io';

const _defaultImportSource = 'ai-estimated-import';

Future<void> main(List<String> args) async {
  final config = _ImportConfig.fromEnvironment();
  final importer = _FoodTemplateImporter(config);
  await importer.run();
}

class _ImportConfig {
  const _ImportConfig({
    required this.supabaseUrl,
    required this.serviceRoleKey,
    required this.inputPath,
    required this.batchSize,
    required this.importSource,
    required this.failureReportPath,
    required this.dryRun,
  });

  final String supabaseUrl;
  final String serviceRoleKey;
  final String inputPath;
  final int batchSize;
  final String importSource;
  final String failureReportPath;
  final bool dryRun;

  String get restBaseUrl => '$supabaseUrl/rest/v1';

  factory _ImportConfig.fromEnvironment() {
    final supabaseUrl = Platform.environment['SUPABASE_URL']?.trim() ?? '';
    final serviceRoleKey =
        Platform.environment['SUPABASE_SERVICE_ROLE_KEY']?.trim() ?? '';
    final inputPath =
        Platform.environment['FOOD_IMAGE_IMPORT_INPUT']?.trim() ?? '';
    final batchSizeRaw =
        Platform.environment['FOOD_IMAGE_IMPORT_BATCH_SIZE']?.trim() ?? '50';
    final importSource =
        Platform.environment['FOOD_IMAGE_IMPORT_SOURCE']?.trim() ??
        _defaultImportSource;
    final failureReportPath =
        Platform.environment['FOOD_IMAGE_IMPORT_FAILURE_REPORT']?.trim() ??
        'tool/food_image_import_failures.json';
    final dryRun = _parseBool(
      Platform.environment['FOOD_IMAGE_IMPORT_DRY_RUN']?.trim(),
    );
    final batchSize = int.tryParse(batchSizeRaw) ?? 50;

    if (supabaseUrl.isEmpty || serviceRoleKey.isEmpty || inputPath.isEmpty) {
      stderr.writeln(
        '缺少 SUPABASE_URL、SUPABASE_SERVICE_ROLE_KEY 或 FOOD_IMAGE_IMPORT_INPUT。',
      );
      stderr.writeln(
        '示例：SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... '
        'FOOD_IMAGE_IMPORT_INPUT=tool/sample_food_image_manifest.json '
        'dart run tool/import_food_images.dart',
      );
      exitCode = 64;
      throw StateError('缺少导入所需环境变量');
    }

    final inputEntityType = FileSystemEntity.typeSync(inputPath);
    final isJsonFile = inputEntityType == FileSystemEntityType.file &&
        inputPath.toLowerCase().endsWith('.json');
    if (!isJsonFile) {
      stderr.writeln('导入输入必须是 JSON 文件: $inputPath');
      exitCode = 64;
      throw StateError('导入输入必须是 JSON 文件');
    }

    return _ImportConfig(
      supabaseUrl: supabaseUrl.replaceAll(RegExp(r'/$'), ''),
      serviceRoleKey: serviceRoleKey,
      inputPath: inputPath,
      batchSize: batchSize < 1 ? 1 : batchSize,
      importSource: importSource.isEmpty ? _defaultImportSource : importSource,
      failureReportPath: failureReportPath,
      dryRun: dryRun,
    );
  }

  static bool _parseBool(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'y':
        return true;
      default:
        return false;
    }
  }
}

class _FoodTemplateImporter {
  _FoodTemplateImporter(this._config) : _client = HttpClient();

  final _ImportConfig _config;
  final HttpClient _client;
  final List<Map<String, dynamic>> _failures = <Map<String, dynamic>>[];

  Future<void> run() async {
    stdout.writeln('开始导入离线食物模板...');
    stdout.writeln('输入文件: ${_config.inputPath}');
    if (_config.dryRun) {
      stdout.writeln('当前为 dry-run，只校验和输出结果，不写入 Supabase。');
    }

    final categories = await _fetchCategories();
    final existingFoods = await _fetchExistingFoods();
    final nextSortByCategoryId = await _fetchExistingSortOrders();
    final templateFoods = await _loadTemplateFoods();
    final report = _ImportReport(totalTemplateFoods: templateFoods.length);
    final insertedRows = <Map<String, dynamic>>[];
    final batchSeenNames = <String>{};
    var nextCategorySortOrder = _nextCategorySortOrder(categories);

    for (final food in templateFoods) {
      final normalizedName = _normalizeName(food.foodName);
      if (!_isValidTemplate(food)) {
        report.skippedInvalidFoods++;
        _failures.add({
          'food_name': food.foodName,
          'reason': '缺少必要字段或营养值不合法',
        });
        continue;
      }
      if (existingFoods.contains(normalizedName)) {
        report.skippedDuplicateFoods++;
        continue;
      }
      if (!batchSeenNames.add(normalizedName)) {
        report.skippedDuplicateFoods++;
        continue;
      }

      try {
        final categoryId = await _ensureCategory(
          categories: categories,
          nextCategorySortOrder: () => nextCategorySortOrder++,
          categoryName: food.categoryName,
        );
        final nextSortOrder = nextSortByCategoryId[categoryId] ?? 0;
        nextSortByCategoryId[categoryId] = nextSortOrder + 1;
        insertedRows.add(
          _buildFoodRow(
            template: food,
            categoryId: categoryId,
            sortOrder: nextSortOrder,
            importIndex: insertedRows.length,
          ),
        );
        existingFoods.add(normalizedName);
      } catch (error) {
        report.failedFoods++;
        _failures.add({
          'food_name': food.foodName,
          'reason': '$error',
        });
      }
    }

    if (!_config.dryRun && insertedRows.isNotEmpty) {
      await _insertFoodsInBatches(insertedRows);
    }

    report.insertedFoods = insertedRows.length;
    await _writeFailureReport();
    _printReport(report);
    _client.close(force: true);
  }

  Future<List<_FoodTemplateItem>> _loadTemplateFoods() async {
    final decoded = jsonDecode(await File(_config.inputPath).readAsString());
    if (decoded is! List) {
      throw StateError('模板 JSON 必须是数组。');
    }
    return decoded
        .whereType<Map>()
        .map((item) => _FoodTemplateItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  bool _isValidTemplate(_FoodTemplateItem item) {
    return item.foodName.trim().isNotEmpty &&
        item.categoryName.trim().isNotEmpty &&
        item.portionText.trim().isNotEmpty &&
        item.nutrition.energyKCal > 0 &&
        item.nutrition.protein >= 0 &&
        item.nutrition.fat >= 0 &&
        item.nutrition.carb >= 0;
  }

  Future<Map<String, _CategoryRow>> _fetchCategories() async {
    final rows = await _getList(
      '${_config.restBaseUrl}/food_categories?select=id,name,sort_order,is_active',
    );
    final categories = <String, _CategoryRow>{};
    for (final row in rows) {
      final category = _CategoryRow.fromJson(row);
      if (category.id.isEmpty || category.name.isEmpty) {
        continue;
      }
      categories[_normalizeName(category.name)] = category;
    }
    return categories;
  }

  Future<Set<String>> _fetchExistingFoods() async {
    final rows = await _getList(
      '${_config.restBaseUrl}/food_catalog_items?select=food_name',
    );
    return rows
        .map((row) => _normalizeName(row['food_name']?.toString() ?? ''))
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  Future<Map<String, int>> _fetchExistingSortOrders() async {
    final rows = await _getList(
      '${_config.restBaseUrl}/food_catalog_items?select=category_id,sort_order',
    );
    final sortOrders = <String, int>{};
    for (final row in rows) {
      final categoryId = row['category_id']?.toString() ?? '';
      if (categoryId.isEmpty) {
        continue;
      }
      final sortOrder = int.tryParse('${row['sort_order'] ?? 0}') ?? 0;
      final current = sortOrders[categoryId];
      if (current == null || sortOrder > current) {
        sortOrders[categoryId] = sortOrder;
      }
    }
    return {
      for (final entry in sortOrders.entries) entry.key: entry.value + 1,
    };
  }

  Future<String> _ensureCategory({
    required Map<String, _CategoryRow> categories,
    required int Function() nextCategorySortOrder,
    required String categoryName,
  }) async {
    final normalizedName = _normalizeName(categoryName);
    final current = categories[normalizedName];
    if (current != null) {
      return current.id;
    }
    if (_config.dryRun) {
      final fakeId = 'dry-run-$normalizedName';
      final sortOrder = nextCategorySortOrder();
      categories[normalizedName] = _CategoryRow(
        id: fakeId,
        name: categoryName.trim(),
        sortOrder: sortOrder,
        isActive: true,
      );
      return fakeId;
    }
    final sortOrder = nextCategorySortOrder();
    final rows = await _postList(
      url: '${_config.restBaseUrl}/food_categories?on_conflict=name',
      body: [
        {
          'name': categoryName.trim(),
          'sort_order': sortOrder,
          'is_active': true,
        },
      ],
      prefer: 'resolution=merge-duplicates,return=representation',
    );
    if (rows.isEmpty) {
      throw StateError('创建分类失败: $categoryName');
    }
    final category = _CategoryRow.fromJson(rows.first);
    categories[normalizedName] = category;
    return category.id;
  }

  int _nextCategorySortOrder(Map<String, _CategoryRow> categories) {
    if (categories.isEmpty) {
      return 0;
    }
    final maxOrder = categories.values
        .map((category) => category.sortOrder)
        .fold<int>(0, (current, value) => value > current ? value : current);
    return maxOrder + 1;
  }

  Map<String, dynamic> _buildFoodRow({
    required _FoodTemplateItem template,
    required String categoryId,
    required int sortOrder,
    required int importIndex,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final code =
        'custom-ai-$timestamp-${(importIndex + 1).toString().padLeft(4, '0')}';
    return {
      'food_code': code,
      'food_name': template.foodName.trim(),
      'category_id': categoryId,
      'edible': template.nutrition.edible,
      'water': template.nutrition.water,
      'energy_kcal': template.nutrition.energyKCal,
      'energy_kj': template.nutrition.energyKJ,
      'protein': template.nutrition.protein,
      'fat': template.nutrition.fat,
      'carb': template.nutrition.carb,
      'dietary_fiber': template.nutrition.dietaryFiber,
      'cholesterol': template.nutrition.cholesterol,
      'ash': template.nutrition.ash,
      'vitamin_a': template.nutrition.vitaminA,
      'carotene': template.nutrition.carotene,
      'retinol': template.nutrition.retinol,
      'thiamin': template.nutrition.thiamin,
      'riboflavin': template.nutrition.riboflavin,
      'niacin': template.nutrition.niacin,
      'vitamin_c': template.nutrition.vitaminC,
      'vitamin_e_total': template.nutrition.vitaminETotal,
      'vitamin_e1': template.nutrition.vitaminE1,
      'vitamin_e2': template.nutrition.vitaminE2,
      'vitamin_e3': template.nutrition.vitaminE3,
      'calcium': template.nutrition.calcium,
      'phosphorus': template.nutrition.phosphorus,
      'potassium': template.nutrition.potassium,
      'sodium': template.nutrition.sodium,
      'magnesium': template.nutrition.magnesium,
      'iron': template.nutrition.iron,
      'zinc': template.nutrition.zinc,
      'selenium': template.nutrition.selenium,
      'copper': template.nutrition.copper,
      'manganese': template.nutrition.manganese,
      'remark': _buildRemark(template),
      'search_keywords': _keywords(
        template.foodName,
        aliases: template.aliases,
      ),
      'sort_order': sortOrder,
      'source': _config.importSource,
      'is_active': true,
    };
  }

  String _buildRemark(_FoodTemplateItem template) {
    final lines = <String>[
      '导入来源: ${_config.importSource}',
      '营养口径: 按截图热量估算',
      '份量说明: ${template.portionText}',
    ];
    if (template.remark != null && template.remark!.trim().isNotEmpty) {
      lines.add(template.remark!.trim());
    }
    if (template.aliases.isNotEmpty) {
      lines.add('别名: ${template.aliases.join('、')}');
    }
    return lines.join(' | ');
  }

  String _keywords(String foodName, {List<String> aliases = const []}) {
    final base = <String>{foodName.trim(), ...aliases.map((alias) => alias.trim())}
      ..removeWhere((item) => item.isEmpty);
    final tokenized = <String>{};
    for (final item in base) {
      final chars = item
          .split('')
          .where((char) => RegExp(r'[\u4e00-\u9fa5a-zA-Z0-9]').hasMatch(char))
          .join(' ');
      if (chars.isNotEmpty) {
        tokenized.add(chars);
      }
    }
    return [...base, ...tokenized].join(' ').trim();
  }

  Future<void> _insertFoodsInBatches(List<Map<String, dynamic>> rows) async {
    for (var i = 0; i < rows.length; i += _config.batchSize) {
      final end = (i + _config.batchSize < rows.length)
          ? i + _config.batchSize
          : rows.length;
      final batch = rows.sublist(i, end);
      await _postList(
        url: '${_config.restBaseUrl}/food_catalog_items',
        body: batch,
        prefer: 'return=minimal',
      );
      stdout.writeln('food_catalog_items 已写入 $end/${rows.length}');
    }
  }

  Future<void> _writeFailureReport() async {
    final file = File(_config.failureReportPath);
    if (file.parent.path.isNotEmpty) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_failures),
    );
    stdout.writeln('失败清单已输出: ${file.path}');
  }

  Future<List<Map<String, dynamic>>> _getList(String url) async {
    final request = await _client.getUrl(Uri.parse(url));
    _addSupabaseHeaders(request);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('请求失败: ${response.statusCode} $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw StateError('响应不是数组: $url');
    }
    return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<List<Map<String, dynamic>>> _postList({
    required String url,
    required List<Map<String, dynamic>> body,
    required String prefer,
  }) async {
    final request = await _client.postUrl(Uri.parse(url));
    _addSupabaseHeaders(request);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set('Prefer', prefer);
    final payload = utf8.encode(jsonEncode(body));
    request.headers.contentLength = payload.length;
    request.add(payload);
    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('写入失败: ${response.statusCode} $responseBody');
    }
    if (responseBody.trim().isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(responseBody);
    if (decoded is! List) {
      throw StateError('写入响应不是数组: $url');
    }
    return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  void _addSupabaseHeaders(HttpClientRequest request) {
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${_config.serviceRoleKey}',
    );
    request.headers.set('apikey', _config.serviceRoleKey);
  }

  void _printReport(_ImportReport report) {
    stdout.writeln('');
    stdout.writeln('导入完成。');
    stdout.writeln('模板食物数: ${report.totalTemplateFoods}');
    stdout.writeln('新增食物数: ${report.insertedFoods}');
    stdout.writeln('跳过重复数: ${report.skippedDuplicateFoods}');
    stdout.writeln('跳过无效数: ${report.skippedInvalidFoods}');
    stdout.writeln('失败数: ${report.failedFoods}');
  }
}

class _FoodTemplateItem {
  const _FoodTemplateItem({
    required this.foodName,
    required this.categoryName,
    required this.portionText,
    required this.nutrition,
    required this.aliases,
    this.remark,
  });

  final String foodName;
  final String categoryName;
  final String portionText;
  final _NutritionPayload nutrition;
  final List<String> aliases;
  final String? remark;

  factory _FoodTemplateItem.fromJson(Map<String, dynamic> json) {
    return _FoodTemplateItem(
      foodName: (json['food_name'] ?? json['foodName'] ?? '').toString().trim(),
      categoryName:
          (json['category_name'] ?? json['categoryName'] ?? '').toString().trim(),
      portionText:
          (json['portion_text'] ?? json['portionText'] ?? '').toString().trim(),
      nutrition: _NutritionPayload.fromJson(json),
      aliases: _readStringList(json['aliases']),
      remark: _readNullableText(json['remark']),
    );
  }
}

class _NutritionPayload {
  const _NutritionPayload({
    required this.edible,
    required this.water,
    required this.energyKCal,
    required this.energyKJ,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.dietaryFiber,
    required this.cholesterol,
    required this.ash,
    required this.vitaminA,
    required this.carotene,
    required this.retinol,
    required this.thiamin,
    required this.riboflavin,
    required this.niacin,
    required this.vitaminC,
    required this.vitaminETotal,
    required this.vitaminE1,
    required this.vitaminE2,
    required this.vitaminE3,
    required this.calcium,
    required this.phosphorus,
    required this.potassium,
    required this.sodium,
    required this.magnesium,
    required this.iron,
    required this.zinc,
    required this.selenium,
    required this.copper,
    required this.manganese,
  });

  final double edible;
  final double water;
  final double energyKCal;
  final double energyKJ;
  final double protein;
  final double fat;
  final double carb;
  final double dietaryFiber;
  final double cholesterol;
  final double ash;
  final double vitaminA;
  final double carotene;
  final double retinol;
  final double thiamin;
  final double riboflavin;
  final double niacin;
  final double vitaminC;
  final double vitaminETotal;
  final double vitaminE1;
  final double vitaminE2;
  final double vitaminE3;
  final double calcium;
  final double phosphorus;
  final double potassium;
  final double sodium;
  final double magnesium;
  final double iron;
  final double zinc;
  final double selenium;
  final double copper;
  final double manganese;

  factory _NutritionPayload.fromJson(Map<String, dynamic> json) {
    return _NutritionPayload(
      edible: _readDouble(json['edible'], fallback: 100) ?? 100,
      water: _readDouble(json['water']) ?? 0,
      energyKCal: _readDouble(json['energy_kcal'] ?? json['energyKCal']) ?? 0,
      energyKJ: _readDouble(json['energy_kj'] ?? json['energyKJ']) ?? 0,
      protein: _readDouble(json['protein']) ?? 0,
      fat: _readDouble(json['fat']) ?? 0,
      carb: _readDouble(json['carb'] ?? json['CHO']) ?? 0,
      dietaryFiber:
          _readDouble(json['dietary_fiber'] ?? json['dietaryFiber']) ?? 0,
      cholesterol: _readDouble(json['cholesterol']) ?? 0,
      ash: _readDouble(json['ash']) ?? 0,
      vitaminA: _readDouble(json['vitamin_a'] ?? json['vitaminA']) ?? 0,
      carotene: _readDouble(json['carotene']) ?? 0,
      retinol: _readDouble(json['retinol']) ?? 0,
      thiamin: _readDouble(json['thiamin']) ?? 0,
      riboflavin: _readDouble(json['riboflavin']) ?? 0,
      niacin: _readDouble(json['niacin']) ?? 0,
      vitaminC: _readDouble(json['vitamin_c'] ?? json['vitaminC']) ?? 0,
      vitaminETotal:
          _readDouble(json['vitamin_e_total'] ?? json['vitaminETotal']) ?? 0,
      vitaminE1: _readDouble(json['vitamin_e1'] ?? json['vitaminE1']) ?? 0,
      vitaminE2: _readDouble(json['vitamin_e2'] ?? json['vitaminE2']) ?? 0,
      vitaminE3: _readDouble(json['vitamin_e3'] ?? json['vitaminE3']) ?? 0,
      calcium: _readDouble(json['calcium'] ?? json['Ca']) ?? 0,
      phosphorus: _readDouble(json['phosphorus'] ?? json['P']) ?? 0,
      potassium: _readDouble(json['potassium'] ?? json['K']) ?? 0,
      sodium: _readDouble(json['sodium'] ?? json['Na']) ?? 0,
      magnesium: _readDouble(json['magnesium'] ?? json['Mg']) ?? 0,
      iron: _readDouble(json['iron'] ?? json['Fe']) ?? 0,
      zinc: _readDouble(json['zinc'] ?? json['Zn']) ?? 0,
      selenium: _readDouble(json['selenium'] ?? json['Se']) ?? 0,
      copper: _readDouble(json['copper'] ?? json['Cu']) ?? 0,
      manganese: _readDouble(json['manganese'] ?? json['Mn']) ?? 0,
    );
  }
}

class _CategoryRow {
  const _CategoryRow({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  factory _CategoryRow.fromJson(Map<String, dynamic> json) {
    return _CategoryRow(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      isActive: json['is_active'] != false,
    );
  }
}

class _ImportReport {
  _ImportReport({required this.totalTemplateFoods});

  final int totalTemplateFoods;
  int insertedFoods = 0;
  int skippedDuplicateFoods = 0;
  int skippedInvalidFoods = 0;
  int failedFoods = 0;
}

String _normalizeName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

double? _readDouble(Object? raw, {double? fallback}) {
  if (raw == null) {
    return fallback;
  }
  final normalized = raw.toString().trim();
  if (normalized.isEmpty || normalized == '—') {
    return fallback;
  }
  if (normalized.toLowerCase() == 'tr') {
    return 0;
  }
  return double.tryParse(normalized.replaceAll('*', '')) ?? fallback;
}

String? _readNullableText(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty || value == '—') {
    return null;
  }
  return value;
}

List<String> _readStringList(Object? raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}
