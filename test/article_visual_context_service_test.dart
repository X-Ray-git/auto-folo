import 'package:flutter_test/flutter_test.dart';
import 'package:fourier/models/article.dart';
import 'package:fourier/services/article_visual_context_service.dart';

void main() {
  test('dedupes raster images, excludes SVG and caps shared context', () {
    final html = [
      for (var index = 0; index < 10; index++)
        '<img src="https://example.com/$index.png">',
      '<img src="https://example.com/0.png">',
      '<img src="https://example.com/vector.svg">',
    ].join();
    final article = ArticleModel(
      entryId: 'visual-context',
      feedId: 'feed',
      feedTitle: '测试源',
      title: '多图文章',
      url: 'https://example.com/article',
      content: html,
    );

    final context = ArticleVisualContextService.prepare(article, html);

    expect(context.totalImageCount, 10);
    expect(
      context.imageUrls,
      List.generate(8, (index) => 'https://example.com/$index.png'),
    );
    expect(context.structureMetadata, contains('正文图片总数：10'));
    expect(context.structureMetadata, contains('本轮可用正文图片数：8'));
  });
}
