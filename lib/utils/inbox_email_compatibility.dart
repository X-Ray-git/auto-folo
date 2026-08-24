import 'package:html/dom.dart' as dom;

/// Normalizes presentation-heavy Inbox email HTML into reader content.
///
/// Inbox is the stable boundary: mailbox IDs and sender templates can change,
/// while all Inbox entries need the same presentation reset. This keeps
/// semantic content and actions intact and only removes email-client styling.
abstract final class InboxEmailCompatibility {
  static bool appliesTo({String? category}) {
    return category?.trim().toLowerCase() == 'inbox';
  }

  static void apply(dom.DocumentFragment fragment) {
    _stripEmailPresentation(fragment);
  }

  static void _stripEmailPresentation(dom.DocumentFragment fragment) {
    const removableAttributes = {
      'align',
      'bgcolor',
      'border',
      'cellpadding',
      'cellspacing',
      'class',
      'height',
      'role',
      'style',
      'valign',
      'width',
    };

    for (final element in fragment.querySelectorAll('*')) {
      final tag = element.localName;
      // Layout tables are flattened later. Tables that survive that pass are
      // semantic data tables and keep their own table-specific attributes.
      if (tag == 'table' || tag == 'tr' || tag == 'td' || tag == 'th') {
        continue;
      }
      if (tag == 'img') {
        _preserveImageDimensions(element);
        element.attributes.remove('class');
        element.attributes.remove('style');
        continue;
      }
      for (final attribute in removableAttributes) {
        element.attributes.remove(attribute);
      }
    }
  }

  static void _preserveImageDimensions(dom.Element image) {
    final style = image.attributes['style'] ?? '';
    for (final property in const ['width', 'height']) {
      final explicit = image.attributes[property]?.trim() ?? '';
      if (double.tryParse(explicit) != null) continue;

      final match = RegExp(
        '(?:^|;)\\s*$property\\s*:\\s*(\\d+(?:\\.\\d+)?)px'
        '(?:\\s*!important)?(?:;|\$)',
        caseSensitive: false,
      ).firstMatch(style);
      final value = match?.group(1);
      if (value != null) {
        image.attributes[property] = value;
      } else {
        image.attributes.remove(property);
      }
    }
  }
}
