import 'package:flutter_test/flutter_test.dart';

import 'package:fourier/pages/article/article_navigation.dart';

void main() {
  test('related article returns instead of advancing after mark read', () {
    var returnCount = 0;
    var nextCount = 0;

    ArticleNavigationPolicy.afterMarkedRead(
      wasUnread: true,
      returnToPrevious: () => returnCount++,
      goNext: () => nextCount++,
    );

    expect(returnCount, 1);
    expect(nextCount, 0);
  });

  test('regular article advances when no related return is available', () {
    var nextCount = 0;

    ArticleNavigationPolicy.afterMarkedRead(
      wasUnread: true,
      goNext: () => nextCount++,
    );

    expect(nextCount, 1);
  });

  test('restoring unread does not trigger post-read navigation', () {
    var returnCount = 0;
    var nextCount = 0;

    ArticleNavigationPolicy.afterMarkedRead(
      wasUnread: false,
      returnToPrevious: () => returnCount++,
      goNext: () => nextCount++,
    );

    expect(returnCount, 0);
    expect(nextCount, 0);
  });
}
