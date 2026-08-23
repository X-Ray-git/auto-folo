import 'package:flutter_test/flutter_test.dart';
import 'package:fourier/services/animation_activity_monitor.dart';

void main() {
  setUp(AnimationActivityMonitor.resetForTesting);
  tearDown(AnimationActivityMonitor.resetForTesting);

  test('reports active and mounted components without content identifiers', () {
    final active = Object();
    final inactive = Object();
    AnimationActivityMonitor.register(
      active,
      AnimationActivityKind.imagePlaceholder,
      active: true,
    );
    AnimationActivityMonitor.register(
      inactive,
      AnimationActivityKind.imagePlaceholder,
    );

    expect(AnimationActivityMonitor.takeSnapshot(), {
      'registeredTotal': 2,
      'activeTotal': 1,
      'components': {
        'imagePlaceholder': {
          'registered': 2,
          'active': 1,
          'started': 1,
          'stopped': 0,
        },
      },
    });
  });

  test('tracks state transitions and resets only interval counters', () {
    final token = Object();
    AnimationActivityMonitor.register(
      token,
      AnimationActivityKind.mediaLoading,
      active: true,
    );
    AnimationActivityMonitor.update(
      token,
      AnimationActivityKind.nativeVideoPlaying,
      active: true,
    );

    final first = AnimationActivityMonitor.takeSnapshot();
    expect(first['registeredTotal'], 1);
    expect(first['activeTotal'], 1);
    expect(first['components'], {
      'mediaLoading': {
        'registered': 0,
        'active': 0,
        'started': 1,
        'stopped': 1,
      },
      'nativeVideoPlaying': {
        'registered': 1,
        'active': 1,
        'started': 1,
        'stopped': 0,
      },
    });

    expect(AnimationActivityMonitor.takeSnapshot(), {
      'registeredTotal': 1,
      'activeTotal': 1,
      'components': {
        'nativeVideoPlaying': {
          'registered': 1,
          'active': 1,
          'started': 0,
          'stopped': 0,
        },
      },
    });
  });

  test('unregister records a stop without allowing negative counts', () {
    final token = Object();
    AnimationActivityMonitor.register(
      token,
      AnimationActivityKind.syncSpinner,
      active: true,
    );
    AnimationActivityMonitor.unregister(token);
    AnimationActivityMonitor.unregister(token);

    expect(AnimationActivityMonitor.takeSnapshot(), {
      'registeredTotal': 0,
      'activeTotal': 0,
      'components': {
        'syncSpinner': {
          'registered': 0,
          'active': 0,
          'started': 1,
          'stopped': 1,
        },
      },
    });
  });
}
