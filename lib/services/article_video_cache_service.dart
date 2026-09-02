import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:synchronized/synchronized.dart';

import '../utils/storage.dart';

/// Source classification used by the video error surface and cache policy.
enum ArticleVideoSourceKind { expiringCdn, direct, embedded }

/// Result of the lightweight HTTP status probe for a signed media URL.
enum ArticleVideoProbeResult { notApplicable, reachable, expired, networkError }

/// Best-effort cache for videos that the user has actually started playing.
///
/// Video URLs from social feeds frequently contain short-lived signatures. The
/// URL is not a durable identity, so the cache key deliberately excludes
/// known authorization parameters. A completed local file can therefore still
/// be used after the source URL has expired, while a new URL for the same media
/// can reuse the existing file.
abstract final class ArticleVideoCacheService {
  static const Duration cacheStalePeriod = Duration(days: 30);
  static const int macosMaxCachedVideos = 64;
  static const int androidMaxCachedVideos = 24;
  static const int maxCachedFileBytes = 200 * 1024 * 1024;
  static const int macosCacheBudgetBytes = 1024 * 1024 * 1024;
  static const int androidCacheBudgetBytes = 300 * 1024 * 1024;

  static const String _cacheName = 'fourier_video_cache_v1';
  static const String _cacheKeyPrefix = 'article-video-v1';
  static const String _indexStorageKey = '__article_video_cache_index_v1__';
  static const Duration _probeTimeout = Duration(seconds: 5);
  static const Set<String> _volatileQueryKeys = {
    'auth',
    'auth_key',
    'deadline',
    'dis_t',
    'e',
    'expires',
    'hdntl',
    'key-pair-id',
    'pkey',
    'session',
    'sessionid',
    'sec_token',
    'sig',
    'signature',
    'sign',
    'ssig',
    'token',
    'ws_secret',
    'ws_time',
    'wssecret',
    'wstime',
  };

  static final CacheManager _defaultCacheManager = CacheManager(
    Config(
      _cacheName,
      stalePeriod: cacheStalePeriod,
      maxNrOfCacheObjects: Platform.isAndroid
          ? androidMaxCachedVideos
          : macosMaxCachedVideos,
    ),
  );

  static final Map<String, Future<void>> _inFlight = {};
  static final Lock _indexLock = Lock();
  static final Map<String, _VideoCacheIndexEntry> _index = {};
  static int _generation = 0;
  static bool _indexHydrated = false;
  static bool? _enabledOverrideForTesting;
  static BaseCacheManager? _cacheManagerOverrideForTesting;

  static BaseCacheManager get _cacheManager =>
      _cacheManagerOverrideForTesting ?? _defaultCacheManager;

  static bool get _enabled =>
      _enabledOverrideForTesting ?? (Platform.isMacOS || Platform.isAndroid);

  static int get maxCachedVideos =>
      Platform.isAndroid ? androidMaxCachedVideos : macosMaxCachedVideos;

  static int get cacheBudgetBytes =>
      Platform.isAndroid ? androidCacheBudgetBytes : macosCacheBudgetBytes;

  @visibleForTesting
  static void setEnabledForTesting(bool? enabled) {
    _enabledOverrideForTesting = enabled;
  }

  @visibleForTesting
  static void setCacheManagerForTesting(BaseCacheManager? manager) {
    _cacheManagerOverrideForTesting = manager;
  }

  /// Whether this URL represents a direct media resource that can be cached.
  /// HTML embed pages are intentionally excluded; they have their own player.
  static bool isCacheableUrl(String rawUrl) {
    final uri = _parse(rawUrl);
    if (uri == null) return false;
    if (_isStreamingManifest(uri)) return false;
    final host = uri.host.toLowerCase();
    if (host == 'www.youtube-nocookie.com' ||
        host == 'www.youtube.com' ||
        host == 'youtube.com' ||
        host == 'youtu.be' ||
        host == 'player.bilibili.com' ||
        host.endsWith('.bilibili.com')) {
      return false;
    }
    return true;
  }

  static ArticleVideoSourceKind sourceKind(String rawUrl) {
    final uri = _parse(rawUrl);
    if (uri == null) return ArticleVideoSourceKind.direct;
    final host = uri.host.toLowerCase();
    if (host == 'www.youtube-nocookie.com' ||
        host == 'www.youtube.com' ||
        host == 'youtube.com' ||
        host == 'youtu.be' ||
        host == 'player.bilibili.com' ||
        host.endsWith('.bilibili.com')) {
      return ArticleVideoSourceKind.embedded;
    }
    if (host.contains('weibocdn') ||
        host == 'video.weibo.com' ||
        host == 'mpvideo.qpic.cn' ||
        _hasVolatileQuery(uri)) {
      return ArticleVideoSourceKind.expiringCdn;
    }
    return ArticleVideoSourceKind.direct;
  }

  static bool isLikelyExpiringUrl(String rawUrl) =>
      sourceKind(rawUrl) == ArticleVideoSourceKind.expiringCdn;

  static String sourceLabel(String rawUrl) {
    final host = _parse(rawUrl)?.host.toLowerCase() ?? '';
    if (host.contains('weibo')) return '微博';
    if (host == 'mpvideo.qpic.cn') return '腾讯视频';
    return '来源';
  }

  static String expiryMessage(String rawUrl) {
    final label = sourceLabel(rawUrl);
    if (isLikelyExpiringUrl(rawUrl)) {
      return '$label提供的是临时播放地址，播放器无法为历史链接续期。'
          '成功播放的视频会尝试保存到本地，之后可在地址失效后继续播放。';
    }
    return '媒体服务拒绝了当前地址，可能是临时签名或访问权限已失效。';
  }

  /// Performs a header-only-ish range request so the app can see an HTTP
  /// status that platform video players may hide. The response body is
  /// cancelled immediately; servers that ignore Range therefore cannot cause
  /// a full video download here.
  static Future<ArticleVideoProbeResult> probeAvailability(
    String rawUrl,
  ) async {
    if (!isLikelyExpiringUrl(rawUrl)) {
      return ArticleVideoProbeResult.notApplicable;
    }
    final probe = await _probeMedia(rawUrl);
    return probe.result;
  }

  static Future<_MediaProbe> _probeMedia(String rawUrl) async {
    final uri = _parse(rawUrl);
    if (uri == null) {
      return const _MediaProbe(ArticleVideoProbeResult.networkError);
    }

    final client = HttpClient()
      ..connectionTimeout = _probeTimeout
      ..idleTimeout = _probeTimeout;
    try {
      final request = await client.getUrl(uri).timeout(_probeTimeout);
      request
        ..followRedirects = true
        ..maxRedirects = 5
        ..headers.set(HttpHeaders.userAgentHeader, _videoHeaders['User-Agent']!)
        ..headers.set(HttpHeaders.acceptHeader, _videoHeaders['Accept']!)
        ..headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');

      final response = await request.close().timeout(_probeTimeout);
      final statusCode = response.statusCode;
      final totalBytes = _responseTotalBytes(response);
      final subscription = response.listen((_) {});
      await subscription.cancel();
      return _MediaProbe(
        probeResultForStatus(statusCode),
        totalBytes,
        statusCode >= 200 && statusCode < 300,
      );
    } on TimeoutException {
      return const _MediaProbe(ArticleVideoProbeResult.networkError);
    } on SocketException {
      return const _MediaProbe(ArticleVideoProbeResult.networkError);
    } on HttpException {
      return const _MediaProbe(ArticleVideoProbeResult.networkError);
    } catch (_) {
      return const _MediaProbe(ArticleVideoProbeResult.networkError);
    } finally {
      client.close(force: true);
    }
  }

  @visibleForTesting
  static ArticleVideoProbeResult probeResultForStatus(int statusCode) {
    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      return ArticleVideoProbeResult.expired;
    }
    return ArticleVideoProbeResult.reachable;
  }

  /// Returns a locally cached file even when the cache manager considers its
  /// metadata stale. This is intentional: the remote URL may expire before
  /// the local media file should be discarded.
  static Future<File?> getCachedFile({
    required String articleId,
    required String videoUrl,
  }) async {
    if (!_enabled || articleId.isEmpty || !isCacheableUrl(videoUrl)) {
      return null;
    }
    try {
      final info = await _cacheManager.getFileFromCache(
        cacheKey(articleId, videoUrl),
        ignoreMemCache: true,
      );
      final file = info?.file;
      if (file == null || !await file.exists() || await file.length() == 0) {
        return null;
      }
      await _recordCacheEntry(
        cacheKey(articleId, videoUrl),
        await file.length(),
      );
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Drops a local file that failed media initialization so it cannot poison
  /// future attempts with the same stable cache key.
  static Future<void> removeCachedFile({
    required String articleId,
    required String videoUrl,
  }) async {
    if (!_enabled || articleId.isEmpty || !isCacheableUrl(videoUrl)) return;
    try {
      final key = cacheKey(articleId, videoUrl);
      await _cacheManager.removeFile(key);
      await _indexLock.synchronized(() async {
        _ensureIndexHydrated();
        if (_index.remove(key) != null) await _persistIndex();
      });
    } catch (_) {
      // Cache cleanup is best effort and must not mask the network fallback.
    }
  }

  /// Warms the cache after a network video has initialized successfully.
  /// It never blocks the first frame and never retries indefinitely.
  static void warmVideo({required String articleId, required String videoUrl}) {
    if (!_enabled || articleId.isEmpty || !isCacheableUrl(videoUrl)) return;

    final key = cacheKey(articleId, videoUrl);
    if (_inFlight.containsKey(key)) return;
    final generation = _generation;
    final future = _warmVideo(
      videoUrl: videoUrl,
      key: key,
      generation: generation,
    );
    _inFlight[key] = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_inFlight[key], future)) _inFlight.remove(key);
      }),
    );
  }

  static Future<void> _warmVideo({
    required String videoUrl,
    required String key,
    required int generation,
  }) async {
    try {
      final cached = await _cacheManager.getFileFromCache(
        key,
        ignoreMemCache: true,
      );
      if (cached != null &&
          await cached.file.exists() &&
          await cached.file.length() > 0) {
        return;
      }

      final probe = await _probeMedia(videoUrl);
      if (!probe.canDownload ||
          probe.totalBytes == null ||
          probe.totalBytes! <= 0 ||
          probe.totalBytes! > maxCachedFileBytes) {
        return;
      }

      final info = await _cacheManager.downloadFile(
        videoUrl,
        key: key,
        authHeaders: _videoHeaders,
        force: true,
      );
      if (generation != _generation) {
        await _cacheManager.removeFile(key);
        return;
      }
      if (!await info.file.exists() || await info.file.length() == 0) {
        await _cacheManager.removeFile(key);
        return;
      }
      final bytes = await info.file.length();
      if (bytes > maxCachedFileBytes) {
        await _cacheManager.removeFile(key);
        return;
      }
      await _recordCacheEntry(key, bytes);
    } catch (_) {
      // Caching is opportunistic. Playback has already succeeded and must not
      // surface a second error merely because the background copy failed.
    }
  }

  /// Clears video files when the active Folo account changes.
  static Future<void> resetForAccountChange() async {
    _generation++;
    await _cacheManager.emptyCache();
    await _indexLock.synchronized(() async {
      _index.clear();
      _indexHydrated = true;
      await _persistIndex();
    });
  }

  @visibleForTesting
  static String cacheKey(String articleId, String videoUrl) {
    final identity = _stableMediaIdentity(videoUrl);
    final digest = sha256.convert(utf8.encode(identity)).toString();
    return '$_cacheKeyPrefix:${articleId.length}:$articleId:$digest';
  }

  @visibleForTesting
  static String stableMediaIdentity(String videoUrl) =>
      _stableMediaIdentity(videoUrl);

  static Uri? _parse(String rawUrl) {
    final normalized = rawUrl.trim().startsWith('//')
        ? 'https:${rawUrl.trim()}'
        : rawUrl.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  static bool _hasVolatileQuery(Uri uri) => uri.queryParameters.keys.any(
    (key) => _volatileQueryKeys.contains(key.toLowerCase()),
  );

  static bool _isStreamingManifest(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.endsWith('.m3u8') ||
        path.endsWith('.mpd') ||
        path.endsWith('.ism') ||
        path.endsWith('.isml');
  }

  static int? _responseTotalBytes(HttpClientResponse response) {
    final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
    final rangeMatch = contentRange == null
        ? null
        : RegExp(r'/([0-9]+)$').firstMatch(contentRange.trim());
    final rangeTotal = int.tryParse(rangeMatch?.group(1) ?? '');
    if (rangeTotal != null && rangeTotal > 0) return rangeTotal;
    if (response.statusCode == HttpStatus.ok && response.contentLength > 0) {
      return response.contentLength;
    }
    return null;
  }

  static Future<void> _recordCacheEntry(String key, int bytes) {
    return _indexLock.synchronized(() async {
      _ensureIndexHydrated();
      _index[key] = _VideoCacheIndexEntry(
        bytes: bytes,
        lastAccessedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _enforceBudget();
      await _persistIndex();
    });
  }

  static void _ensureIndexHydrated() {
    if (_indexHydrated) return;
    try {
      final raw = GStorage.localCache.get(_indexStorageKey);
      if (raw is Map) {
        for (final entry in raw.entries) {
          if (entry.key is! String || entry.value is! Map) continue;
          final value = Map<dynamic, dynamic>.from(entry.value as Map);
          final bytes = value['bytes'];
          final lastAccessedAt = value['lastAccessedAt'];
          if (bytes is int && bytes > 0 && lastAccessedAt is int) {
            _index[entry.key as String] = _VideoCacheIndexEntry(
              bytes: bytes,
              lastAccessedAt: lastAccessedAt,
            );
          }
        }
      }
      _indexHydrated = true;
    } catch (_) {
      // Tests and very early startup may not have initialized Hive yet.
    }
  }

  static Future<void> _enforceBudget() async {
    final entries = _index.entries.toList()
      ..sort(
        (a, b) => a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt),
      );
    var total = entries.fold<int>(0, (sum, entry) => sum + entry.value.bytes);
    for (final entry in entries) {
      if (total <= cacheBudgetBytes) break;
      try {
        await _cacheManager.removeFile(entry.key);
      } catch (_) {
        // Removing metadata still prevents a stale entry from pinning budget.
      }
      total -= entry.value.bytes;
      _index.remove(entry.key);
    }
  }

  static Future<void> _persistIndex() async {
    try {
      await GStorage.localCache.put(
        _indexStorageKey,
        _index.map((key, value) => MapEntry(key, value.toJson())),
      );
    } catch (_) {
      // Cache metadata is opportunistic and must never break playback.
    }
  }

  static String _stableMediaIdentity(String rawUrl) {
    final uri = _parse(rawUrl);
    if (uri == null) return rawUrl.trim();

    final stableQuery =
        uri.queryParameters.entries
            .where(
              (entry) => !_volatileQueryKeys.contains(entry.key.toLowerCase()),
            )
            .map((entry) => MapEntry(entry.key.toLowerCase(), entry.value))
            .toList()
          ..sort((a, b) {
            final keyOrder = a.key.compareTo(b.key);
            return keyOrder == 0 ? a.value.compareTo(b.value) : keyOrder;
          });
    final query = stableQuery
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');
    return [
      uri.host.toLowerCase(),
      uri.path,
      if (query.isNotEmpty) query,
    ].join('?');
  }

  static const Map<String, String> _videoHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36',
    'Accept': 'video/*,application/octet-stream;q=0.9,*/*;q=0.8',
  };
}

class _MediaProbe {
  const _MediaProbe(this.result, [this.totalBytes, this.canDownload = false]);

  final ArticleVideoProbeResult result;
  final int? totalBytes;
  final bool canDownload;
}

class _VideoCacheIndexEntry {
  const _VideoCacheIndexEntry({
    required this.bytes,
    required this.lastAccessedAt,
  });

  final int bytes;
  final int lastAccessedAt;

  Map<String, int> toJson() => {
    'bytes': bytes,
    'lastAccessedAt': lastAccessedAt,
  };
}
