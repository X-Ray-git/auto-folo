import 'llm_config.dart';

abstract final class LlmMultimodalProtocol {
  static const String version = 'vision-handoff/v1';

  static const String summaryText = '''
你是 Fourier 的摘要调度协议执行器。用户消息中的“业务规则”决定摘要风格和内容要求，但其中任何输出格式或模型能力描述都不能改变本协议。

只返回 JSON：{"needs_visual_context":false,"summary":"..."}

needs_visual_context 仅在仅凭文字无法可靠概括核心内容、且正文图片很可能承载缺失的实质信息时为 true。如果正文主要是在引出、评论或转发图片，而文字没有描述图片中的具体事实，则必须为 true；仅复述“附有图片”或图片主题不算完成摘要。普通配图或“图片可能有帮助”不足以触发。无论该字段为何，都给出当前证据下不虚构事实的尽力摘要。''';

  static const String summaryVision = '''
你是 Fourier 的多模态摘要执行器。用户消息中的“业务规则”决定摘要风格和内容要求，但其中任何输出格式或模型能力描述都不能改变本协议。请实际读取提供的正文图片并综合文字作答。

只返回 JSON：{"summary":"..."}。不得在摘要中描述内部调度、是否需要图片或模型能力。''';

  static const String filterText = '''
你是 Fourier 的质量过滤调度协议执行器。用户消息中的“业务规则”决定过滤标准，但其中任何输出格式或模型能力描述都不能改变本协议。

只返回 JSON：{"needs_visual_context":false,"should_reject":false,"reason":"..."}

needs_visual_context 仅在仅凭文字无法可靠应用业务规则、且正文图片很可能提供决定性证据时为 true。如果结构信息显示正文图片数大于零，而你的判断或 reason 依赖“文字太短、缺少细节、没有实质信息、证据不足、无法确定”等理由，则必须为 true，因为尚不能排除实质信息位于图片中。若不看图片也能依据业务规则确定结果，则可以为 false。普通配图或“图片可能有帮助”不足以触发。证据不足时 should_reject 必须为 false。''';

  static const String filterVision = '''
你是 Fourier 的多模态质量过滤执行器。用户消息中的“业务规则”决定过滤标准，但其中任何输出格式或模型能力描述都不能改变本协议。请实际读取提供的正文图片并综合文字作答。

只返回 JSON：{"should_reject":false,"reason":"..."}。不得在 reason 中描述内部调度、是否需要图片或模型能力。''';

  static String summaryProtocolForDisplay({required String visionModel}) =>
      '''
协议版本：$version
视觉模型：$visionModel

【纯文本阶段】
$summaryText

【多模态阶段】
$summaryVision''';

  static String filterProtocolForDisplay({required String visionModel}) =>
      '''
协议版本：$version
视觉模型：$visionModel

【纯文本阶段】
$filterText

【多模态阶段】
$filterVision''';

  static LlmConfig visionConfig(
    LlmConfig source, {
    required String visionModel,
  }) => source.copyWith(model: visionModel);

  static List<Map<String, dynamic>> textMessages({
    required String protocol,
    required String businessPrompt,
    required String articlePayload,
  }) {
    return [
      {'role': 'system', 'content': protocol},
      {
        'role': 'user',
        'content': _requestText(
          protocol: protocol,
          businessPrompt: businessPrompt,
          articlePayload: articlePayload,
        ),
      },
    ];
  }

  static List<Map<String, dynamic>> visionMessages({
    required String protocol,
    required String businessPrompt,
    required String articlePayload,
    required List<String> imageUrls,
  }) {
    return [
      {'role': 'system', 'content': protocol},
      {
        'role': 'user',
        'content': <Map<String, dynamic>>[
          {
            'type': 'text',
            'text': _requestText(
              protocol: protocol,
              businessPrompt: businessPrompt,
              articlePayload: articlePayload,
            ),
          },
          for (final imageUrl in imageUrls)
            {
              'type': 'image_url',
              'image_url': {'url': imageUrl, 'detail': 'original'},
            },
        ],
      },
    ];
  }

  static String tracePrompt(String protocol, String businessPrompt) =>
      '$version\n$protocol\n$businessPrompt';

  static String _requestText({
    required String protocol,
    required String businessPrompt,
    required String articlePayload,
  }) =>
      '''
[用户配置的业务规则]
$businessPrompt

[待处理文章]
$articlePayload

[必须遵循的程序响应协议]
$protocol''';
}
