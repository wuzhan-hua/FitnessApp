import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/exercise_catalog_constants.dart';
import '../../domain/entities/workout_models.dart';
import '../../utils/app_error.dart';
import '../../utils/app_logger.dart';

class ExerciseCatalogService {
  ExerciseCatalogService(this._client);

  static const unlabeledEquipment = '未标注';
  static const _bucketName = 'exercise-reference';
  static const _cacheDataKey = 'exercise_catalog_cache_json_v1';
  static const _cacheUpdatedAtKey = 'exercise_catalog_cache_updated_at_v1';
  static const _refreshInterval = Duration(hours: 24);

  static const List<String> _equipmentOrder = [
    '杠铃',
    '哑铃',
    '器械',
    '绳索',
    '壶铃',
    '弹力带',
    '徒手',
    '健身球',
    '药球',
    'EZ 弯举杠',
    '泡沫轴',
    '其他',
    unlabeledEquipment,
  ];

  final SupabaseClient _client;
  List<ExerciseCatalogItem>? _memoryCache;
  Future<List<ExerciseCatalogItem>>? _catalogLoadFuture;
  Future<bool>? _refreshFuture;

  Future<Set<String>> getDefaultZeroWeightExerciseIds(
    Iterable<String> exerciseIds,
  ) async {
    final ids = exerciseIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      return const <String>{};
    }
    try {
      final rows = await _client
          .from('exercise_catalog_items')
          .select('id, equipment_en, equipment_zh, category_en, category_zh')
          .inFilter('id', ids)
          .eq('is_active', true);
      final result = <String>{};
      for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
        final item = ExerciseCatalogItem.fromJson(row);
        if (item.defaultsToZeroWeight) {
          result.add(item.id);
        }
      }
      return result;
    } catch (error, stackTrace) {
      AppLogger.error(
        '加载默认零负重动作失败',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppError.from(
        error,
        fallbackMessage: '加载动作元数据失败，请稍后重试。',
      );
    }
  }

  Future<List<String>> getPrimaryMuscleGroups() async {
    final items = await _getCatalogItems();
    final available = <String>[];
    for (final entry in ExerciseCatalogConstants.muscleTargets.entries) {
      if (items.any((item) => _matchesMuscleGroup(item, entry.key))) {
        available.add(entry.key);
      }
    }
    if (items.any(_isCardioExercise)) {
      available.add(ExerciseCatalogConstants.cardioGroup);
    }
    return available;
  }

  Future<List<String>> getEquipmentsByMuscleGroup(String muscleGroup) async {
    final items = await getExercises(muscleGroup: muscleGroup);
    final values = items.map(_equipmentLabelOf).toSet().toList();
    values.sort(_compareEquipments);
    return values;
  }

  Future<List<ExerciseCatalogItem>> getExercises({
    required String muscleGroup,
    String? equipment,
  }) async {
    final items = await _getCatalogItems();
    final filtered = items.where((item) {
      if (!_matchesGroup(item, muscleGroup)) {
        return false;
      }
      if (equipment == null || equipment.isEmpty) {
        return true;
      }
      return _equipmentLabelOf(item) == equipment;
    }).toList();
    filtered.sort((a, b) => _displayNameOf(a).compareTo(_displayNameOf(b)));
    return filtered;
  }

  Future<bool> refreshCatalogIfStale() {
    final ongoing = _refreshFuture;
    if (ongoing != null) {
      return ongoing;
    }
    final future = _refreshCatalogIfStaleInternal();
    _refreshFuture = future;
    future.whenComplete(() {
      _refreshFuture = null;
    });
    return future;
  }

  Future<List<ExerciseCatalogItem>> _getCatalogItems() {
    if (_memoryCache != null) {
      return Future.value(_memoryCache!);
    }
    final ongoing = _catalogLoadFuture;
    if (ongoing != null) {
      return ongoing;
    }
    final future = _loadCatalogItems();
    _catalogLoadFuture = future;
    future.whenComplete(() {
      _catalogLoadFuture = null;
    });
    return future;
  }

  Future<List<ExerciseCatalogItem>> _loadCatalogItems() async {
    final cachedItems = await _readCatalogCache();
    if (cachedItems.isNotEmpty) {
      _memoryCache = cachedItems;
      return cachedItems;
    }
    final remoteItems = await _fetchAllActiveExercisesRemote();
    _memoryCache = remoteItems;
    await _writeCatalogCache(remoteItems);
    return remoteItems;
  }

  Future<bool> _refreshCatalogIfStaleInternal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatedAtMillis = prefs.getInt(_cacheUpdatedAtKey);
      final updatedAt = updatedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedAtMillis);
      final isFresh =
          updatedAt != null &&
          DateTime.now().difference(updatedAt) < _refreshInterval;
      if (isFresh) {
        return false;
      }
      final remoteItems = await _fetchAllActiveExercisesRemote();
      _memoryCache = remoteItems;
      await _writeCatalogCache(remoteItems, prefs: prefs);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('后台刷新动作目录失败', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<List<ExerciseCatalogItem>> _fetchAllActiveExercisesRemote() async {
    try {
      final rows = await _client
          .from('exercise_catalog_items')
          .select()
          .eq('is_active', true)
          .order('name_en');
      return (rows as List<dynamic>)
          .map((row) => _mapRow(row as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      AppLogger.error('加载动作目录失败', error: error, stackTrace: stackTrace);
      throw AppError.from(error, fallbackMessage: '加载动作目录失败，请稍后重试。');
    }
  }

  Future<List<ExerciseCatalogItem>> _readCatalogCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheDataKey);
      if (raw == null || raw.isEmpty) {
        return const [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await _clearCatalogCache(prefs);
        return const [];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ExerciseCatalogItem.fromJson)
          .toList();
    } catch (error, stackTrace) {
      AppLogger.error('读取动作目录缓存失败', error: error, stackTrace: stackTrace);
      final prefs = await SharedPreferences.getInstance();
      await _clearCatalogCache(prefs);
      return const [];
    }
  }

  Future<void> _writeCatalogCache(
    List<ExerciseCatalogItem> items, {
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((item) => item.toJson()).toList());
    await resolvedPrefs.setString(_cacheDataKey, raw);
    await resolvedPrefs.setInt(
      _cacheUpdatedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _clearCatalogCache(SharedPreferences prefs) async {
    await prefs.remove(_cacheDataKey);
    await prefs.remove(_cacheUpdatedAtKey);
  }

  ExerciseCatalogItem _mapRow(Map<String, dynamic> row) {
    final coverPath = row['cover_image_path'] as String?;
    final imagePaths = _readStringList(row['image_paths']);
    return ExerciseCatalogItem.fromJson({
      ...row,
      'cover_image_url': coverPath == null || coverPath.isEmpty
          ? null
          : _client.storage.from(_bucketName).getPublicUrl(coverPath),
      'image_urls': imagePaths
          .map((path) => _client.storage.from(_bucketName).getPublicUrl(path))
          .toList(),
    });
  }

  bool _matchesMuscleGroup(ExerciseCatalogItem item, String group) {
    final targets = ExerciseCatalogConstants.muscleTargets[group];
    if (targets == null || targets.isEmpty) {
      return false;
    }
    return item.primaryMusclesZh.any(targets.contains);
  }

  bool _matchesGroup(ExerciseCatalogItem item, String group) {
    if (group == ExerciseCatalogConstants.cardioGroup) {
      return _isCardioExercise(item);
    }
    return _matchesMuscleGroup(item, group);
  }

  bool _isCardioExercise(ExerciseCatalogItem item) {
    return item.categoryEn?.trim().toLowerCase() == 'cardio' ||
        item.categoryZh?.trim() == ExerciseCatalogConstants.cardioGroup;
  }

  String _equipmentLabelOf(ExerciseCatalogItem item) {
    final zh = item.equipmentZh?.trim();
    if (zh != null && zh.isNotEmpty) {
      return zh;
    }
    final en = item.equipmentEn?.trim();
    if (en != null && en.isNotEmpty) {
      return en;
    }
    return unlabeledEquipment;
  }

  String _displayNameOf(ExerciseCatalogItem item) {
    final zh = item.nameZh?.trim();
    if (zh != null && zh.isNotEmpty) {
      return zh;
    }
    return item.nameEn;
  }

  int _compareEquipments(String a, String b) {
    final indexA = _equipmentOrder.indexOf(a);
    final indexB = _equipmentOrder.indexOf(b);
    if (indexA == -1 && indexB == -1) {
      return a.compareTo(b);
    }
    if (indexA == -1) {
      return 1;
    }
    if (indexB == -1) {
      return -1;
    }
    return indexA.compareTo(indexB);
  }

  List<String> _readStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
