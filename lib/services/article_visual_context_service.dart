import '../models/article.dart';
import '../utils/article_content_utils.dart';
import 'article_image_service.dart';

class ArticleVisualContext {
  const ArticleVisualContext({
    required this.imageUrls,
    required this.totalImageCount,
  });

  final List<String> imageUrls;
  final int totalImageCount;

  bool get hasImages => imageUrls.isNotEmpty;

  String get structureMetadata =>
      '''
[结构信息]
正文图片总数：$totalImageCount
本轮可用正文图片数：${imageUrls.length}''';
}

/// 摘要和质量过滤共用的正文图片选择规则。
abstract final class ArticleVisualContextService {
  static const int maxImagesPerRequest = 8;

  static ArticleVisualContext prepare(
    ArticleModel article,
    String normalizedHtml,
  ) {
    final allUrls = ArticleContentUtils.extractImageUrls(
      normalizedHtml,
      sourceUrl: article.url,
    ).where((url) => !ArticleImageService.isSvg(url)).toList(growable: false);

    return ArticleVisualContext(
      imageUrls: List.unmodifiable(allUrls.take(maxImagesPerRequest)),
      totalImageCount: allUrls.length,
    );
  }
}
