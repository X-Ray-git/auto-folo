import 'dart:async';
import 'dart:io';

import 'package:fourier/services/article_video_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArticleVideoCacheService policy', () {
    test('recognizes expiring social-media media URLs', () {
      expect(
        ArticleVideoCacheService.sourceKind(
          'https://f.video.weibocdn.com/path/video.mp4?Expires=1&Signature=old',
        ),
        ArticleVideoSourceKind.expiringCdn,
      );
      expect(
        ArticleVideoCacheService.sourceKind(
          'https://mpvideo.qpic.cn/path/video.mp4?dis_t=1',
        ),
        ArticleVideoSourceKind.expiringCdn,
      );
      expect(
        ArticleVideoCacheService.expiryMessage(
          'https://f.video.weibocdn.com/path/video.mp4?Expires=1',
        ),
        allOf(contains('微博'), contains('临时播放地址'), contains('本地')),
      );
    });

    test('maps HTTP authorization failures to an expired result', () {
      expect(
        ArticleVideoCacheService.probeResultForStatus(401),
        ArticleVideoProbeResult.expired,
      );
      expect(
        ArticleVideoCacheService.probeResultForStatus(403),
        ArticleVideoProbeResult.expired,
      );
      expect(
        ArticleVideoCacheService.probeResultForStatus(206),
        ArticleVideoProbeResult.reachable,
      );
      expect(
        ArticleVideoCacheService.probeResultForStatus(500),
        ArticleVideoProbeResult.reachable,
      );
    });

    test('probes the HTTP status without downloading the media body', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <HttpRequest>[];
      final subscription = server.listen((request) async {
        requests.add(request);
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.addStream(
          Stream<List<int>>.fromIterable([List<int>.filled(1024, 1)]),
        );
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      final result = await ArticleVideoCacheService.probeAvailability(
        'http://${server.address.host}:${server.port}/video.mp4?Expires=1',
      );

      expect(result, ArticleVideoProbeResult.expired);
      expect(requests, hasLength(1));
      expect(
        requests.single.headers.value(HttpHeaders.rangeHeader),
        'bytes=0-0',
      );
    });

    test('does not treat embed pages as cacheable direct media', () {
      expect(
        ArticleVideoCacheService.isCacheableUrl(
          'https://www.youtube-nocookie.com/embed/video-id',
        ),
        isFalse,
      );
      expect(
        ArticleVideoCacheService.sourceKind(
          'https://player.bilibili.com/player.html?bvid=BV1test',
        ),
        ArticleVideoSourceKind.embedded,
      );
      expect(
        ArticleVideoCacheService.isCacheableUrl(
          'https://video.twimg.com/ext_tw_video/1/pu/vid/1280x720/video.mp4',
        ),
        isTrue,
      );
      expect(
        ArticleVideoCacheService.isCacheableUrl(
          'https://cdn.example.com/master.m3u8?token=temporary',
        ),
        isFalse,
      );
      expect(
        ArticleVideoCacheService.isCacheableUrl(
          'https://cdn.example.com/manifest.mpd',
        ),
        isFalse,
      );
    });

    test('keeps per-file and platform cache budgets bounded', () {
      expect(ArticleVideoCacheService.maxCachedFileBytes, 200 * 1024 * 1024);
      expect(
        ArticleVideoCacheService.macosCacheBudgetBytes,
        1024 * 1024 * 1024,
      );
      expect(
        ArticleVideoCacheService.androidCacheBudgetBytes,
        300 * 1024 * 1024,
      );
      expect(
        ArticleVideoCacheService.cacheBudgetBytes,
        greaterThanOrEqualTo(ArticleVideoCacheService.maxCachedFileBytes),
      );
    });

    test('keeps a stable cache identity when signatures rotate', () {
      const oldUrl =
          'https://f.video.weibocdn.com/path/video.mp4?id=media-1&Expires=1&Signature=old';
      const newUrl =
          'https://f.video.weibocdn.com/path/video.mp4?Signature=new&Expires=2&id=media-1';

      expect(
        ArticleVideoCacheService.stableMediaIdentity(oldUrl),
        ArticleVideoCacheService.stableMediaIdentity(newUrl),
      );
      expect(
        ArticleVideoCacheService.cacheKey('entry', oldUrl),
        ArticleVideoCacheService.cacheKey('entry', newUrl),
      );
    });

    test('keeps Tencent cache identity stable across dis_t changes', () {
      const oldUrl = 'https://mpvideo.qpic.cn/path/video.mp4?dis_t=1';
      const newUrl = 'https://mpvideo.qpic.cn/path/video.mp4?dis_t=2';

      expect(
        ArticleVideoCacheService.cacheKey('entry', oldUrl),
        ArticleVideoCacheService.cacheKey('entry', newUrl),
      );
    });

    test('separates different media and articles', () {
      final first = ArticleVideoCacheService.cacheKey(
        'entry-a',
        'https://example.com/video-a.mp4',
      );
      final secondMedia = ArticleVideoCacheService.cacheKey(
        'entry-a',
        'https://example.com/video-b.mp4',
      );
      final secondArticle = ArticleVideoCacheService.cacheKey(
        'entry-b',
        'https://example.com/video-a.mp4',
      );

      expect(first, isNot(secondMedia));
      expect(first, isNot(secondArticle));
      expect(ArticleVideoCacheService.maxCachedVideos, greaterThan(0));
    });
  });
}
