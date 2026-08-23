import 'package:flutter/foundation.dart';

enum AnimationActivityKind {
  articleView('articleView'),
  shimmer('shimmer'),
  articleBodyLoading('articleBodyLoading'),
  imagePlaceholder('imagePlaceholder'),
  articleCardStatusSpinner('articleCardStatusSpinner'),
  controlSpinner('controlSpinner'),
  pageLoadingSpinner('pageLoadingSpinner'),
  syncSpinner('syncSpinner'),
  qualityFilterSpinner('qualityFilterSpinner'),
  relationSpinner('relationSpinner'),
  mediaLoading('mediaLoading'),
  nativeVideoPlaying('nativeVideoPlaying'),
  webViewVisible('webViewVisible');

  const AnimationActivityKind(this.logName);

  final String logName;
}

@immutable
final class _AnimationActivityState {
  const _AnimationActivityState({required this.kind, required this.active});

  final AnimationActivityKind kind;
  final bool active;
}

/// Anonymous lifecycle counters for UI states that may continuously request
/// frames. Updates happen only when a component starts, stops, mounts, or
/// unmounts; the energy sampler reads the aggregate snapshot every 15 seconds.
abstract final class AnimationActivityMonitor {
  static final Map<Object, _AnimationActivityState> _states = {};
  static final Map<AnimationActivityKind, int> _starts = {};
  static final Map<AnimationActivityKind, int> _stops = {};

  static void register(
    Object token,
    AnimationActivityKind kind, {
    bool active = false,
  }) {
    final previous = _states[token];
    if (previous != null) {
      unregister(token);
    }
    _states[token] = _AnimationActivityState(kind: kind, active: active);
    if (active) _increment(_starts, kind);
  }

  static void update(
    Object token,
    AnimationActivityKind kind, {
    required bool active,
  }) {
    final previous = _states[token];
    if (previous == null) {
      register(token, kind, active: active);
      return;
    }
    if (previous.kind == kind && previous.active == active) return;

    if (previous.active) _increment(_stops, previous.kind);
    if (active) _increment(_starts, kind);
    _states[token] = _AnimationActivityState(kind: kind, active: active);
  }

  static void unregister(Object token) {
    final previous = _states.remove(token);
    if (previous?.active ?? false) _increment(_stops, previous!.kind);
  }

  static Map<String, Object> takeSnapshot() {
    final registered = <AnimationActivityKind, int>{};
    final active = <AnimationActivityKind, int>{};
    for (final state in _states.values) {
      _increment(registered, state.kind);
      if (state.active) _increment(active, state.kind);
    }

    final components = <String, Object>{};
    for (final kind in AnimationActivityKind.values) {
      final registeredCount = registered[kind] ?? 0;
      final activeCount = active[kind] ?? 0;
      final startedCount = _starts[kind] ?? 0;
      final stoppedCount = _stops[kind] ?? 0;
      if (registeredCount == 0 && startedCount == 0 && stoppedCount == 0) {
        continue;
      }
      components[kind.logName] = <String, int>{
        'registered': registeredCount,
        'active': activeCount,
        'started': startedCount,
        'stopped': stoppedCount,
      };
    }

    final snapshot = <String, Object>{
      'registeredTotal': _states.length,
      'activeTotal': active.values.fold<int>(0, (sum, value) => sum + value),
      'components': components,
    };
    _starts.clear();
    _stops.clear();
    return snapshot;
  }

  static void _increment(
    Map<AnimationActivityKind, int> target,
    AnimationActivityKind kind,
  ) {
    target[kind] = (target[kind] ?? 0) + 1;
  }

  @visibleForTesting
  static void resetForTesting() {
    _states.clear();
    _starts.clear();
    _stops.clear();
  }
}
