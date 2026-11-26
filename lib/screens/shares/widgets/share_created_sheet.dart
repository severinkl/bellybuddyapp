import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/share_launcher_provider.dart';
import '../../../utils/logger.dart';
import '../../../widgets/common/bb_bottom_sheet.dart';
import '../../../widgets/common/bb_button.dart';

/// Shows the [link] and [code] of a share: the link to send or copy, the
/// code to tell separately. [title] is „Link und Code" for an existing share.
Future<void> showShareSecretSheet(
  BuildContext context, {
  required String link,
  required String code,
  String title = 'Link und Code',
}) {
  return showBbBottomSheet<void>(
    context: context,
    builder: (_) => _ShareSecretSheet(title: title, link: link, code: code),
  );
}

/// „482913" as „482 913".
String groupCode(String code) =>
    code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

class _ShareSecretSheet extends ConsumerStatefulWidget {
  const _ShareSecretSheet({
    required this.title,
    required this.link,
    required this.code,
  });

  final String title;
  final String link;
  final String code;

  @override
  ConsumerState<_ShareSecretSheet> createState() => _ShareSecretSheetState();
}

class _ShareSecretSheetState extends ConsumerState<_ShareSecretSheet> {
  static const _log = AppLogger('ShareSecretSheet');

  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    try {
      await ref.read(shareLauncherProvider)(
        'Hier ist mein Belly Buddy Tagebuch: ${widget.link}',
      );
    } catch (e, st) {
      _log.error('opening the share sheet failed', e, st);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(AppConstants.copiedLabelDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppConstants.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap16,
          SelectableText(
            widget.link,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap16,
          Row(
            children: [
              Expanded(
                child: BbButton(
                  label: 'Link senden',
                  icon: Icons.ios_share,
                  onPressed: () => unawaited(_send()),
                ),
              ),
              const SizedBox(width: AppConstants.spacing12),
              Expanded(
                child: BbButton(
                  label: _copied ? 'Kopiert' : 'Kopieren',
                  icon: _copied ? Icons.check : Icons.copy,
                  isOutlined: true,
                  onPressed: () => unawaited(_copy()),
                ),
              ),
            ],
          ),
          AppConstants.gap24,
          Center(
            child: SelectableText(
              groupCode(widget.code),
              style: const TextStyle(
                fontSize: AppTheme.fontSizeDisplayLG,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
                letterSpacing: AppTheme.codeLetterSpacing,
              ),
            ),
          ),
          AppConstants.gap8,
          const Text(
            'Sag ihn deiner Berater:in getrennt vom Link.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
