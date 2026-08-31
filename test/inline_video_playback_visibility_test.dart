import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fourier/pages/article/widgets/inline_video_player.dart';

void main() {
  test('pauses when the article route or main tab becomes inactive', () {
    expect(
      InlineVideoPlaybackVisibility.shouldPause(
        tickerEnabled: false,
        fullscreenActive: false,
        lifecycleState: AppLifecycleState.resumed,
      ),
      isTrue,
    );
  });

  test('keeps the shared controller playing in its fullscreen route', () {
    expect(
      InlineVideoPlaybackVisibility.shouldPause(
        tickerEnabled: false,
        fullscreenActive: true,
        lifecycleState: AppLifecycleState.resumed,
      ),
      isFalse,
    );
  });

  test('pauses in the background even while fullscreen is active', () {
    expect(
      InlineVideoPlaybackVisibility.shouldPause(
        tickerEnabled: false,
        fullscreenActive: true,
        lifecycleState: AppLifecycleState.paused,
      ),
      isTrue,
    );
  });

  test('does not pause the visible foreground article', () {
    expect(
      InlineVideoPlaybackVisibility.shouldPause(
        tickerEnabled: true,
        fullscreenActive: false,
        lifecycleState: AppLifecycleState.resumed,
      ),
      isFalse,
    );
  });
}
