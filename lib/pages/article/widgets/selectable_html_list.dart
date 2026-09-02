import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

typedef SelectableHtmlFragmentBuilder = Widget Function(String html);

/// Renders a semantic HTML list as selectable rows.
///
/// flutter_html's native list-item layout has the correct hanging indent, but
/// its block/list wrapper path can introduce WidgetSpans into the selection
/// stream on Flutter 3.47. Keeping the marker in a fixed column and rendering
/// each item's inline content separately avoids both the WidgetSpan issue and
/// the fragile `after: '\n'` pseudo-content approach.
class SelectableHtmlList extends StatelessWidget {
  const SelectableHtmlList({
    super.key,
    required this.html,
    required this.buildFragment,
    required this.markerStyle,
    this.rootIndent = 20,
    this.nestedIndent = 20,
  });

  final String html;
  final SelectableHtmlFragmentBuilder buildFragment;
  final TextStyle markerStyle;
  final double rootIndent;
  final double nestedIndent;

  @override
  Widget build(BuildContext context) {
    final fragment = html_parser.parseFragment(html);
    final root = _rootList(fragment);
    if (root == null) {
      return SizedBox(width: double.infinity, child: buildFragment(html));
    }
    return _buildList(root, depth: 0);
  }

  dom.Element? _rootList(dom.DocumentFragment fragment) {
    for (final node in fragment.nodes) {
      if (node is! dom.Element) continue;
      final tag = node.localName?.toLowerCase();
      if (tag == 'ul' || tag == 'ol') return node;
    }
    return fragment.querySelector('ul, ol');
  }

  Widget _buildList(dom.Element list, {required int depth}) {
    final ordered = list.localName?.toLowerCase() == 'ol';
    final items = list.children
        .where((child) => child.localName?.toLowerCase() == 'li')
        .toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();

    var ordinal = int.tryParse(list.attributes['start'] ?? '') ?? 1;
    final markers = <String>[];
    for (final item in items) {
      final explicitValue = int.tryParse(item.attributes['value'] ?? '');
      if (explicitValue != null) ordinal = explicitValue;
      markers.add(ordered ? '${ordinal++}.' : '•');
    }

    final markerWidth = _markerWidth(markers);
    final rows = <Widget>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final parts = _buildItemParts(item, depth: depth);
      final body = parts.length == 1
          ? parts.single
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: parts,
            );

      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: markerWidth,
              child: Text(markers[index], style: markerStyle),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    final listBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? rootIndent : nestedIndent),
      child: listBody,
    );
  }

  double _markerWidth(List<String> markers) {
    final longest = markers.fold<int>(
      1,
      (current, marker) => math.max(current, marker.length),
    );
    return math.max(20.0, longest * 9.0 + 4.0);
  }

  List<Widget> _buildItemParts(dom.Element item, {required int depth}) {
    final parts = <Widget>[];
    final inlineHtml = StringBuffer();
    var pendingWhitespace = false;

    void appendBlockSegment(Iterable<dom.Node> nodes) {
      final childrenHtml = nodes.map(_serializeNode).join();
      if (!_hasVisibleContent(childrenHtml)) return;
      if (inlineHtml.isNotEmpty) inlineHtml.write('<br><br>');
      inlineHtml.write(childrenHtml);
    }

    void flushInline() {
      final html = inlineHtml.toString().trim();
      inlineHtml.clear();
      pendingWhitespace = false;
      if (html.isEmpty || !_hasVisibleContent(html)) return;
      parts.add(SizedBox(width: double.infinity, child: buildFragment(html)));
    }

    void appendNode(dom.Node node) {
      if (node is dom.Text) {
        final text = node.data;
        if (text.trim().isEmpty) {
          pendingWhitespace = true;
          return;
        }
        if (pendingWhitespace && inlineHtml.isNotEmpty) {
          inlineHtml.write(' ');
        }
        pendingWhitespace = false;
        inlineHtml.write(htmlEscape.convert(text));
        return;
      }

      if (node is! dom.Element) return;
      final tag = node.localName?.toLowerCase();
      if (tag == 'ul' || tag == 'ol') {
        pendingWhitespace = false;
        flushInline();
        parts.add(_buildList(node, depth: depth + 1));
        return;
      }

      if (tag == 'p' || tag == 'div') {
        pendingWhitespace = false;
        final hasBlockChild = node.nodes.any((child) {
          if (child is! dom.Element) return false;
          final childTag = child.localName?.toLowerCase();
          return childTag == 'p' ||
              childTag == 'div' ||
              childTag == 'ul' ||
              childTag == 'ol';
        });
        if (hasBlockChild) {
          for (final child in node.nodes) {
            appendNode(child);
          }
        } else {
          appendBlockSegment(node.nodes);
        }
        return;
      }

      if (pendingWhitespace && inlineHtml.isNotEmpty) {
        inlineHtml.write(' ');
      }
      pendingWhitespace = false;
      inlineHtml.write(node.outerHtml);
    }

    for (final node in item.nodes) {
      appendNode(node);
    }
    flushInline();

    if (parts.isEmpty) return [const SizedBox.shrink()];
    return parts;
  }

  String _serializeNode(dom.Node node) {
    if (node is dom.Element) return node.outerHtml;
    return htmlEscape.convert(node.text ?? '');
  }

  bool _hasVisibleContent(String html) {
    if (html.trim().isEmpty) return false;
    final fragment = html_parser.parseFragment(html);
    final text = (fragment.text ?? '').replaceAll(
      RegExp(r'[\s\u00a0\u200b-\u200d\u2060\ufeff]'),
      '',
    );
    return text.isNotEmpty ||
        fragment.querySelector('img, iframe, video, audio') != null;
  }
}
