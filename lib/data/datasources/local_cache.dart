import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localCacheProvider = Provider<LocalCache>((ref) {
  return LocalCache();
});

class LocalCache {
  static const _prefix = 'dolpin_cache_';
  static const _ttlSuffix = '_ttl';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Stores JSON-serializable data with optional TTL.
  Future<void> put(String key, dynamic data, {Duration? ttl}) async {
    final prefs = await _instance;
    final json = jsonEncode(data);
    await prefs.setString('$_prefix$key', json);
    if (ttl != null) {
      final expiry = DateTime.now().add(ttl).millisecondsSinceEpoch;
      await prefs.setInt('$_prefix$key$_ttlSuffix', expiry);
    }
  }

  /// Retrieves cached data. Returns null if expired or not found.
  Future<T?> get<T>(String key) async {
    final prefs = await _instance;

    // Check TTL
    final ttlKey = '$_prefix$key$_ttlSuffix';
    final expiry = prefs.getInt(ttlKey);
    if (expiry != null && DateTime.now().millisecondsSinceEpoch > expiry) {
      await remove(key);
      return null;
    }

    final json = prefs.getString('$_prefix$key');
    if (json == null) return null;
    return jsonDecode(json) as T;
  }

  /// Gets cached list of maps (common pattern for model lists).
  Future<List<Map<String, dynamic>>?> getList(String key) async {
    final data = await get<List<dynamic>>(key);
    return data?.cast<Map<String, dynamic>>();
  }

  Future<void> remove(String key) async {
    final prefs = await _instance;
    await prefs.remove('$_prefix$key');
    await prefs.remove('$_prefix$key$_ttlSuffix');
  }

  Future<void> clearAll() async {
    final prefs = await _instance;
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
