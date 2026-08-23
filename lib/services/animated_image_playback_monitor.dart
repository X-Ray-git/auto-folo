import 'package:flutter/foundation.dart';

@immutable
final class AnimatedImagePlaybackState {
  const AnimatedImagePlaybackState({
    required this.windowActive,
    required this.nearViewport,
    required this.streamAttached,
    required this.hasFrame,
  });

  final bool windowActive;
  final bool nearViewport;
  final bool streamAttached;
  final bool hasFrame;

  @override
  bool operator ==(Object other) {
    return other is AnimatedImagePlaybackState &&
        other.windowActive == windowActive &&
        other.nearViewport == nearViewport &&
        other.streamAttached == streamAttached &&
        other.hasFrame == hasFrame;
  }

  @override
  int get hashCode =>
      Object.hash(windowActive, nearViewport, streamAttached, hasFrame);
}

/// In-memory counters for diagnosing animated-image energy use.
///
/// This service never stores image URLs, article IDs, or other content.
abstract final class AnimatedImagePlaybackMonitor {
  static final Map<Object, AnimatedImagePlaybackState> _states = {};
  static int _frameCallbacks = 0;
  static int _streamResolves = 0;
  static int _streamErrors = 0;
  static int _stateChanges = 0;

  static void register(Object token) {
    _states[token] = const AnimatedImagePlaybackState(
      windowActive: true,
      nearViewport: false,
      streamAttached: false,
      hasFrame: false,
    );
  }

  static void unregister(Object token) {
    _states.remove(token);
  }

  static void update(
    Object token, {
    required bool windowActive,
    required bool nearViewport,
    required bool streamAttached,
    required bool hasFrame,
  }) {
    final next = AnimatedImagePlaybackState(
      windowActive: windowActive,
      nearViewport: nearViewport,
      streamAttached: streamAttached,
      hasFrame: hasFrame,
    );
    if (_states[token] == next) return;
    _states[token] = next;
    _stateChanges++;
  }

  static void recordFrameCallback() {
    _frameCallbacks++;
  }

  static void recordStreamResolve() {
    _streamResolves++;
  }

  static void recordStreamError() {
    _streamErrors++;
  }

  static Map<String, int> takeSnapshot() {
    var nearViewport = 0;
    var streamAttached = 0;
    var withFrame = 0;
    var frozenOffscreen = 0;
    var frozenInactive = 0;
    var attachedWaitingForFirstFrame = 0;
    var detachedWaitingForFirstFrame = 0;

    for (final state in _states.values) {
      if (state.nearViewport) nearViewport++;
      if (state.hasFrame) withFrame++;
      if (state.streamAttached) {
        streamAttached++;
        if (!state.hasFrame) attachedWaitingForFirstFrame++;
      } else if (!state.windowActive && state.hasFrame) {
        frozenInactive++;
      } else if (!state.nearViewport && state.hasFrame) {
        frozenOffscreen++;
      } else if (!state.hasFrame) {
        detachedWaitingForFirstFrame++;
      }
    }

    final snapshot = <String, int>{
      'registered': _states.length,
      'nearViewport': nearViewport,
      'streamAttached': streamAttached,
      'withFrame': withFrame,
      'frozenOffscreen': frozenOffscreen,
      'frozenInactive': frozenInactive,
      'attachedWaitingForFirstFrame': attachedWaitingForFirstFrame,
      'detachedWaitingForFirstFrame': detachedWaitingForFirstFrame,
      'frameCallbacks': _frameCallbacks,
      'streamResolves': _streamResolves,
      'streamErrors': _streamErrors,
      'stateChanges': _stateChanges,
    };
    _frameCallbacks = 0;
    _streamResolves = 0;
    _streamErrors = 0;
    _stateChanges = 0;
    return snapshot;
  }

  @visibleForTesting
  static void resetForTesting() {
    _states.clear();
    _frameCallbacks = 0;
    _streamResolves = 0;
    _streamErrors = 0;
    _stateChanges = 0;
  }
}
