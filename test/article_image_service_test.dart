import 'package:flutter_test/flutter_test.dart';

import 'package:fourier/services/article_image_service.dart';

void main() {
  test('recognizes direct SVG resources', () {
    expect(
      ArticleImageService.isSvg('https://cdn.example.com/diagram.svg'),
      isTrue,
    );
  });

  test('does not treat auto-formatted proxy output as SVG', () {
    const url =
        'https://substackcdn.com/image/fetch/'
        r'$s_!hash!,w_1456,c_limit,f_auto,q_auto:good/'
        'https%3A%2F%2Fcdn.example.com%2Fdiagram.svg';

    expect(ArticleImageService.isSvg(url), isFalse);
  });

  test('keeps transformed SVG without auto format on the SVG path', () {
    const url =
        'https://cdn.example.com/image/fetch/'
        'w_1456,c_limit/'
        'https%3A%2F%2Forigin.example.com%2Fdiagram.svg';

    expect(ArticleImageService.isSvg(url), isTrue);
  });
}
