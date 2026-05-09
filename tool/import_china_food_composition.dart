import 'dart:convert';
import 'dart:io';

const _categoryMap = {
  'merged_AnimalFat.json': '动物油脂',
  'merged_CerealsAndCerealProducts.json': '谷物及制品',
  'merged_DriedLegumesAndLegumeProducts.json': '豆类及制品',
  'merged_EggsAndEggProducts.json': '蛋类及制品',
  'merged_FishShellfishAndMollusc.json': '鱼虾贝类',
  'merged_FruitsAndFruitProducts.json': '水果及制品',
  'merged_FungiAndAlgae.json': '菌藻类',
  'merged_InfantFoods.json': '婴幼儿食品',
  'merged_MeatAndMeatProduncts.json': '畜肉及制品',
  'merged_MilkAndMilkProducts.json': '奶类及制品',
  'merged_NutsAndSeeds.json': '坚果与种子',
  'merged_Others.json': '其他',
  'merged_PlantOil.json': '植物油',
  'merged_PoultryAndPoultryProducts.json': '禽类及制品',
  'merged_TubersStarchesAndProducts.json': '薯类淀粉及制品',
  'merged_VegetablesAndVegetableProducts.json': '蔬菜及制品',
};

const _preferredCategoryOrder = [
  '畜肉及制品',
  '禽类及制品',
  '蛋类及制品',
  '鱼虾贝类',
  '奶类及制品',
  '豆类及制品',
  '谷物及制品',
  '薯类淀粉及制品',
  '蔬菜及制品',
  '水果及制品',
  '坚果与种子',
  '菌藻类',
  '动物油脂',
  '植物油',
  '婴幼儿食品',
  '其他',
];

Future<void> main() async {
  final config = _ImportConfig.fromEnvironment();
  final importer = _FoodImporter(config);
  await importer.run();
}

class _ImportConfig {
  const _ImportConfig({
    required this.supabaseUrl,
    required this.serviceRoleKey,
    required this.datasetDir,
    required this.batchSize,
  });

  final String supabaseUrl;
  final String serviceRoleKey;
  final String datasetDir;
  final int batchSize;

  String get restBaseUrl => '$supabaseUrl/rest/v1';

  factory _ImportConfig.fromEnvironment() {
    final supabaseUrl = Platform.environment['SUPABASE_URL']?.trim() ?? '';
    final serviceRoleKey =
        Platform.environment['SUPABASE_SERVICE_ROLE_KEY']?.trim() ?? '';
    final datasetDir =
        Platform.environment['CHINA_FOOD_COMPOSITION_DIR']?.trim() ??
        'assets/datasets/china-food-composition';
    final batchSizeRaw =
        Platform.environment['CHINA_FOOD_IMPORT_BATCH_SIZE']?.trim() ?? '100';
    final batchSize = int.tryParse(batchSizeRaw) ?? 100;

    if (supabaseUrl.isEmpty || serviceRoleKey.isEmpty) {
      stderr.writeln('缺少 SUPABASE_URL 或 SUPABASE_SERVICE_ROLE_KEY。');
      stderr.writeln(
        '示例：SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... '
        'dart run tool/import_china_food_composition.dart',
      );
      exitCode = 64;
      throw StateError('缺少导入所需环境变量');
    }
    if (!Directory(datasetDir).existsSync()) {
      stderr.writeln('食物数据目录不存在: $datasetDir');
      exitCode = 64;
      throw StateError('食物数据目录不存在');
    }
    return _ImportConfig(
      supabaseUrl: supabaseUrl.replaceAll(RegExp(r'/$'), ''),
      serviceRoleKey: serviceRoleKey,
      datasetDir: datasetDir.replaceAll(RegExp(r'/$'), ''),
      batchSize: batchSize < 1 ? 1 : batchSize,
    );
  }
}

class _FoodImporter {
  _FoodImporter(this._config) : _client = HttpClient();

  final _ImportConfig _config;
  final HttpClient _client;

  Future<void> run() async {
    stdout.writeln('开始导入中国食物成分数据...');
    final categories = await _upsertCategories();
    final rows = <Map<String, dynamic>>[];
    final seenCodes = <String>{};

    for (final entry in _categoryMap.entries) {
      final file = File('${_config.datasetDir}/${entry.key}');
      final categoryId = categories[entry.value];
      if (categoryId == null) {
        throw StateError('分类未写入: ${entry.value}');
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        throw StateError('${entry.key} 不是数组');
      }
      for (var index = 0; index < decoded.length; index++) {
        final raw = decoded[index];
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final foodCode = '${raw['foodCode'] ?? ''}'.trim();
        final foodName = '${raw['foodName'] ?? ''}'.trim();
        if (foodCode.isEmpty || foodName.isEmpty) {
          continue;
        }
        if (!seenCodes.add(foodCode)) {
          throw StateError('重复 foodCode: $foodCode');
        }
        rows.add(_mapFoodRow(raw, categoryId, index));
      }
    }

    await _upsertInBatches('food_catalog_items?on_conflict=food_code', rows);
    stdout.writeln('导入完成：分类 ${categories.length} 个，食物 ${rows.length} 条。');
    _client.close(force: true);
  }

  Future<Map<String, String>> _upsertCategories() async {
    final rows = _preferredCategoryOrder.asMap().entries.map((entry) {
      return {'name': entry.value, 'sort_order': entry.key, 'is_active': true};
    }).toList();
    await _upsertInBatches('food_categories?on_conflict=name', rows);

    final request = await _client.getUrl(
      Uri.parse('${_config.restBaseUrl}/food_categories?select=id,name'),
    );
    _addHeaders(request);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('读取分类失败: ${response.statusCode} $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw StateError('分类响应不是数组');
    }
    return {
      for (final row in decoded.cast<Map<String, dynamic>>())
        '${row['name']}': '${row['id']}',
    };
  }

  Map<String, dynamic> _mapFoodRow(
    Map<String, dynamic> raw,
    String categoryId,
    int sortOrder,
  ) {
    final foodName = '${raw['foodName'] ?? ''}'.trim();
    return {
      'food_code': '${raw['foodCode'] ?? ''}'.trim(),
      'food_name': foodName,
      'category_id': categoryId,
      'edible': _value(raw['edible'], fallback: 100),
      'water': _value(raw['water']),
      'energy_kcal': _value(raw['energyKCal']),
      'energy_kj': _value(raw['energyKJ']),
      'protein': _value(raw['protein']),
      'fat': _value(raw['fat']),
      'carb': _value(raw['CHO']),
      'dietary_fiber': _value(raw['dietaryFiber']),
      'cholesterol': _value(raw['cholesterol']),
      'ash': _value(raw['ash']),
      'vitamin_a': _value(raw['vitaminA']),
      'carotene': _value(raw['carotene']),
      'retinol': _value(raw['retinol']),
      'thiamin': _value(raw['thiamin']),
      'riboflavin': _value(raw['riboflavin']),
      'niacin': _value(raw['niacin']),
      'vitamin_c': _value(raw['vitaminC']),
      'vitamin_e_total': _value(raw['vitaminETotal']),
      'vitamin_e1': _value(raw['vitaminE1']),
      'vitamin_e2': _value(raw['vitaminE2']),
      'vitamin_e3': _value(raw['vitaminE3']),
      'calcium': _value(raw['Ca']),
      'phosphorus': _value(raw['P']),
      'potassium': _value(raw['K']),
      'sodium': _value(raw['Na']),
      'magnesium': _value(raw['Mg']),
      'iron': _value(raw['Fe']),
      'zinc': _value(raw['Zn']),
      'selenium': _value(raw['Se']),
      'copper': _value(raw['Cu']),
      'manganese': _value(raw['Mn']),
      'remark': _text(raw['remark']),
      'search_keywords': _keywords(foodName),
      'sort_order': sortOrder,
      'source': 'china-food-composition',
      'is_active': true,
    };
  }

  Future<void> _upsertInBatches(
    String path,
    List<Map<String, dynamic>> rows,
  ) async {
    for (var i = 0; i < rows.length; i += _config.batchSize) {
      final end = (i + _config.batchSize < rows.length)
          ? i + _config.batchSize
          : rows.length;
      final batch = rows.sublist(i, end);
      final request = await _client.postUrl(
        Uri.parse('${_config.restBaseUrl}/$path'),
      );
      _addHeaders(request);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(
        'Prefer',
        'resolution=merge-duplicates,return=minimal',
      );
      final payload = utf8.encode(jsonEncode(batch));
      request.headers.contentLength = payload.length;
      request.add(payload);
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('写入失败: ${response.statusCode} $body');
      }
      stdout.writeln('$path 已写入 $end/${rows.length}');
    }
  }

  void _addHeaders(HttpClientRequest request) {
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${_config.serviceRoleKey}',
    );
    request.headers.set('apikey', _config.serviceRoleKey);
  }

  double _value(Object? raw, {double fallback = 0}) {
    final normalized = '${raw ?? ''}'.trim();
    if (normalized.isEmpty || normalized == '—') {
      return fallback;
    }
    if (normalized.toLowerCase() == 'tr') {
      return 0;
    }
    return double.tryParse(normalized.replaceAll('*', '')) ?? fallback;
  }

  String? _text(Object? raw) {
    final value = '${raw ?? ''}'.trim();
    if (value.isEmpty || value == '—') {
      return null;
    }
    return value;
  }

  String _keywords(String foodName) {
    final chars = foodName
        .split('')
        .where((char) => RegExp(r'[\u4e00-\u9fa5a-zA-Z0-9]').hasMatch(char))
        .join(' ');
    return '$foodName $chars'.trim();
  }
}
