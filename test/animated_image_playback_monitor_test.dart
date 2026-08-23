import 'package:flutter_test/flutter_test.dart';
import 'package:fourier/services/animated_image_playback_monitor.dart';

void main() {
  setUp(AnimatedImagePlaybackMonitor.resetForTesting);
  tearDown(AnimatedImagePlaybackMonitor.resetForTesting);

  test('reports anonymous playback state and resets interval counters', () {
    final playing = Object();
    final inactive = Object();
    AnimatedImagePlaybackMonitor.register(playing);
    AnimatedImagePlaybackMonitor.register(inactive);
    AnimatedImagePlaybackMonitor.update(
      playing,
      windowActive: true,
      nearViewport: true,
      streamAttached: true,
      hasFrame: true,
    );
    AnimatedImagePlaybackMonitor.update(
      inactive,
      windowActive: false,
      nearViewport: true,
      streamAttached: false,
      hasFrame: true,
    );
    AnimatedImagePlaybackMonitor.recordFrameCallback();
    AnimatedImagePlaybackMonitor.recordStreamResolve();
    AnimatedImagePlaybackMonitor.recordStreamError();

    expect(AnimatedImagePlaybackMonitor.takeSnapshot(), {
      'registered': 2,
      'nearViewport': 2,
      'streamAttached': 1,
      'withFrame': 2,
      'frozenOffscreen': 0,
      'frozenInactive': 1,
      'attachedWaitingForFirstFrame': 0,
      'detachedWaitingForFirstFrame': 0,
      'frameCallbacks': 1,
      'streamResolves': 1,
      'streamErrors': 1,
      'stateChanges': 2,
    });

    final next = AnimatedImagePlaybackMonitor.takeSnapshot();
    expect(next['registered'], 2);
    expect(next['frameCallbacks'], 0);
    expect(next['streamResolves'], 0);
    expect(next['streamErrors'], 0);
    expect(next['stateChanges'], 0);
  });
}
