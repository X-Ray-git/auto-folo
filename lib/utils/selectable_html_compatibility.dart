import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Keeps parser-split article blocks in a single selectable text flow.
///
/// Flutter 3.47 and flutter_html 3.0 can produce leading WidgetSpans for
/// block-level list wrappers. Besides breaking selection, forcing only `li`
/// inline leaves common `<li><p>...</p></li>` markup with the marker and text
/// on separate lines. This transform removes only those redundant direct
/// wrappers while preserving inline markup and explicit paragraph boundaries.
class SelectableHtmlCompatibility {
  const SelectableHtmlCompatibility._();

  static String normalizeList(String html) {
    final fragment = html_parser.parseFragment(html);

    void addMarkers(dom.Element list, int depth) {
      final ordered = list.localName?.toLowerCase() == 'ol';
      var ordinal = int.tryParse(list.attributes['start'] ?? '') ?? 1;
      final items = list.children
          .where((child) => child.localName?.toLowerCase() == 'li')
          .toList(growable: false);

      for (final item in items) {
        _flattenDirectBlocks(item);

        final explicitValue = int.tryParse(item.attributes['value'] ?? '');
        if (explicitValue != null) ordinal = explicitValue;
        final marker = ordered ? '${ordinal++}.' : '•';
        final indent = List.filled(depth * 4, '\u00a0').join();
        item.nodes.insert(0, dom.Text('$indent$marker '));

        final nestedLists = item.children
            .where((child) {
              final tag = child.localName?.toLowerCase();
              return tag == 'ul' || tag == 'ol';
            })
            .toList(growable: false);
        for (final nested in nestedLists) {
          final nestedIndex = item.nodes.indexOf(nested);
          final previous = nestedIndex > 0 ? item.nodes[nestedIndex - 1] : null;
          final alreadyStartsOnNewLine =
              previous is dom.Element &&
              previous.localName?.toLowerCase() == 'br';
          if (!alreadyStartsOnNewLine) {
            item.nodes.insert(nestedIndex, dom.Element.tag('br'));
          }
          addMarkers(nested, depth + 1);
        }
      }
    }

    for (final list in fragment.querySelectorAll('ul, ol').toList()) {
      final parentTag = list.parent?.localName?.toLowerCase();
      if (parentTag != 'li') addMarkers(list, 0);
    }
    return fragment.nodes.map((node) {
      if (node is dom.Element) return node.outerHtml;
      return htmlEscape.convert(node.text ?? '');
    }).join();
  }

  static void _flattenDirectBlocks(dom.Element item) {
    final segments = <_ListItemSegment>[];
    var inlineNodes = <dom.Node>[];
    var pendingWhitespace = false;

    void flushInline() {
      if (inlineNodes.isEmpty) return;
      segments.add(_ListItemSegment(inlineNodes));
      inlineNodes = <dom.Node>[];
    }

    for (final node in item.nodes.toList(growable: false)) {
      if (node is dom.Text && node.data.trim().isEmpty) {
        pendingWhitespace = true;
        continue;
      }

      final tag = node is dom.Element ? node.localName?.toLowerCase() : null;
      final isBlockWrapper = tag == 'p' || tag == 'div';
      final isNestedList = tag == 'ul' || tag == 'ol';
      if (isBlockWrapper || isNestedList) {
        pendingWhitespace = false;
        flushInline();
        if (isBlockWrapper) {
          final children = node.nodes.toList(growable: false);
          if (children.isNotEmpty) {
            segments.add(_ListItemSegment(children, isBlock: true));
          }
        } else {
          segments.add(_ListItemSegment(<dom.Node>[node], isNestedList: true));
        }
        continue;
      }

      if (pendingWhitespace && inlineNodes.isNotEmpty) {
        inlineNodes.add(dom.Text(' '));
      }
      pendingWhitespace = false;
      inlineNodes.add(node);
    }
    flushInline();

    for (final node in item.nodes.toList(growable: false)) {
      node.remove();
    }
    for (var index = 0; index < segments.length; index++) {
      if (index > 0) {
        final previous = segments[index - 1];
        final current = segments[index];
        final breakCount = previous.isNestedList || current.isNestedList
            ? 1
            : previous.isBlock || current.isBlock
            ? 2
            : 0;
        for (var breakIndex = 0; breakIndex < breakCount; breakIndex++) {
          item.append(dom.Element.tag('br'));
        }
      }
      for (final node in segments[index].nodes) {
        node.remove();
        item.append(node);
      }
    }
  }
}

class _ListItemSegment {
  const _ListItemSegment(
    this.nodes, {
    this.isBlock = false,
    this.isNestedList = false,
  });

  final List<dom.Node> nodes;
  final bool isBlock;
  final bool isNestedList;
}
