class AgileCacheService {
  AgileCacheService._();
  static final AgileCacheService instance = AgileCacheService._();

  final Map<String, dynamic> _store = {};
  final Set<String> _loading = {};

  Future<T> fetch<T>(String cacheKey, Future<T> Function() loader) async {
    if (_store.containsKey(cacheKey)) {
      return _store[cacheKey] as T;
    }
    if (_loading.contains(cacheKey)) {
      return loader();
    }
    _loading.add(cacheKey);
    try {
      final result = await loader();
      _store[cacheKey] = result;
      return result;
    } finally {
      _loading.remove(cacheKey);
    }
  }

  void invalidate(String cacheKey) {
    _store.remove(cacheKey);
  }

  void invalidateAll() {
    _store.clear();
  }
}
