import 'package:flutter/foundation.dart';

/// Identifies how an article route was opened without coupling the article
/// view to a specific platform navigator.
enum ArticleOpenOrigin { standard, related }

/// Shared post-read navigation semantics for desktop and mobile article views.
abstract final class ArticleNavigationPolicy {
  static void afterMarkedRead({
    required bool wasUnread,
    VoidCallback? returnToPrevious,
    VoidCallback? goNext,
  }) {
    if (!wasUnread) return;
    if (returnToPrevious != null) {
      returnToPrevious();
      return;
    }
    goNext?.call();
  }
}
