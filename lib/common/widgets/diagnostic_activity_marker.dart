import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../services/animation_activity_monitor.dart';

/// Connects a mounted UI state to [AnimationActivityMonitor] without changing
/// layout, painting, hit testing, or animation behavior.
class DiagnosticActivityMarker extends StatefulWidget {
  const DiagnosticActivityMarker({
    super.key,
    required this.kind,
    required this.child,
    this.active = true,
  });

  final AnimationActivityKind kind;
  final bool active;
  final Widget child;

  @override
  State<DiagnosticActivityMarker> createState() =>
      _DiagnosticActivityMarkerState();
}

class _DiagnosticActivityMarkerState extends State<DiagnosticActivityMarker> {
  final Object _token = Object();
  bool? _publishedActive;

  bool get _enabled => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    if (_enabled) AnimationActivityMonitor.register(_token, widget.kind);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _publish();
  }

  @override
  void didUpdateWidget(covariant DiagnosticActivityMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind || oldWidget.active != widget.active) {
      _publish(force: oldWidget.kind != widget.kind);
    }
  }

  void _publish({bool force = false}) {
    if (!_enabled) return;
    final active = widget.active && TickerMode.valuesOf(context).enabled;
    if (!force && _publishedActive == active) return;
    _publishedActive = active;
    AnimationActivityMonitor.update(_token, widget.kind, active: active);
  }

  @override
  void dispose() {
    if (_enabled) AnimationActivityMonitor.unregister(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
