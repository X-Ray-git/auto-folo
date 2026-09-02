import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:fourier/services/article_state_notifier.dart';

void main() {
  test('tick increments the global and target article versions only', () {
    final targetId = 'notifier-target-${DateTime.now().microsecondsSinceEpoch}';
    final otherId = 'notifier-other-${DateTime.now().microsecondsSinceEpoch}';
    final targetVersion = ArticleStateNotifier.versionFor(targetId);
    final otherVersion = ArticleStateNotifier.versionFor(otherId);
    final globalBefore = ArticleStateNotifier.version.value;
    final targetBefore = targetVersion.value;
    final otherBefore = otherVersion.value;

    ArticleStateNotifier.tick(targetId);

    expect(ArticleStateNotifier.version.value, globalBefore + 1);
    expect(targetVersion.value, targetBefore + 1);
    expect(otherVersion.value, otherBefore);
    expect(ArticleStateNotifier.lastEntryId, targetId);
  });

  test('tickAll invalidates every article-specific version', () {
    final firstId = 'notifier-first-${DateTime.now().microsecondsSinceEpoch}';
    final secondId = 'notifier-second-${DateTime.now().microsecondsSinceEpoch}';
    final firstVersion = ArticleStateNotifier.versionFor(firstId);
    final secondVersion = ArticleStateNotifier.versionFor(secondId);
    final globalBefore = ArticleStateNotifier.version.value;
    final firstBefore = firstVersion.value;
    final secondBefore = secondVersion.value;

    ArticleStateNotifier.tickAll();

    expect(ArticleStateNotifier.version.value, globalBefore + 1);
    expect(firstVersion.value, firstBefore + 1);
    expect(secondVersion.value, secondBefore + 1);
    expect(ArticleStateNotifier.lastEntryId, isNull);
  });

  testWidgets('an article-specific observer ignores unrelated ticks', (
    tester,
  ) async {
    final targetId = 'observer-target-${DateTime.now().microsecondsSinceEpoch}';
    final otherId = 'observer-other-${DateTime.now().microsecondsSinceEpoch}';
    var buildCount = 0;

    await tester.pumpWidget(
      Obx(() {
        ArticleStateNotifier.versionFor(targetId).value;
        buildCount++;
        return const SizedBox.shrink();
      }),
    );

    expect(buildCount, 1);
    ArticleStateNotifier.tick(otherId);
    await tester.pump();
    expect(buildCount, 1);

    ArticleStateNotifier.tick(targetId);
    await tester.pump();
    expect(buildCount, 2);
  });
}
