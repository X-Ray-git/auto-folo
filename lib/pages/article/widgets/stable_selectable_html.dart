import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

/// Keeps flutter_html's parser element alive while the rendered HTML is the
/// same.
///
/// flutter_html creates an internal GlobalKey when [Html] is constructed. A
/// new Html widget with the same data therefore replaces HtmlParser and its
/// RenderParagraph, which also drops an active SelectionArea highlight. The
/// parser still needs to be replaced when the data or an explicitly supplied
/// render configuration changes, so those inputs rotate the anchor key.
class StableSelectableHtml extends StatefulWidget {
  const StableSelectableHtml({
    super.key,
    required this.data,
    this.style = const {},
    this.onLinkTap,
    this.onAnchorTap,
    this.extensions = const [],
    this.onCssParseError,
    this.shrinkWrap = false,
    this.onlyRenderTheseTags,
    this.doNotRenderTheseTags,
    this.renderConfigurationKey,
  });

  final String data;
  final Map<String, Style> style;
  final OnTap? onLinkTap;
  final OnTap? onAnchorTap;
  final List<HtmlExtension> extensions;
  final OnCssParseError? onCssParseError;
  final bool shrinkWrap;
  final Set<String>? onlyRenderTheseTags;
  final Set<String>? doNotRenderTheseTags;

  /// Changes to styling/layout inputs that are not encoded in [data] should
  /// pass a stable, comparable value here.
  final Object? renderConfigurationKey;

  @override
  State<StableSelectableHtml> createState() => _StableSelectableHtmlState();
}

class _StableSelectableHtmlState extends State<StableSelectableHtml> {
  GlobalKey _anchorKey = GlobalKey();

  @override
  void didUpdateWidget(covariant StableSelectableHtml oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.renderConfigurationKey != widget.renderConfigurationKey) {
      _anchorKey = GlobalKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Html(
      anchorKey: _anchorKey,
      data: widget.data,
      onLinkTap: widget.onLinkTap,
      onAnchorTap: widget.onAnchorTap,
      extensions: widget.extensions,
      onCssParseError: widget.onCssParseError,
      shrinkWrap: widget.shrinkWrap,
      style: widget.style,
      onlyRenderTheseTags: widget.onlyRenderTheseTags,
      doNotRenderTheseTags: widget.doNotRenderTheseTags,
    );
  }
}
