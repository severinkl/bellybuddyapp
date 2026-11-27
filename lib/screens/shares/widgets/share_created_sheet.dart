import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/data_share.dart';
import '../../../providers/share_launcher_provider.dart';
import '../../../utils/logger.dart';
import '../../../utils/share_origin.dart';
import '../../../widgets/common/bb_bottom_sheet.dart';
import '../../../widgets/common/bb_button.dart';

/// Shows the link and code of a share: the link to send or copy, the code
/// to tell separately. [title] is „Link und Code" for an existing share.
Future<void> showShareSecretSheet(
  BuildContext context,
  ShareSecret secret, {
  String title = 'Link und Code',
}) {
  return showBbBottomSheet<void>(
    context: context,
    builder: (_) => _ShareSecretSheet(title: title, secret: secret),
  );
}

/// The live region around the copy button.
const shareCopiedLiveKey = ValueKey('share-copied-live');

/// „482913" as „482 913".
String groupCode(String code) =>
    code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

class _ShareSecretSheet extends ConsumerStatefulWidget {
  const _ShareSecretSheet({required this.title, required this.secret});

  final String title;
  final ShareSecret secret;

  @override
  ConsumerState<_ShareSecretSheet> createState() => _ShareSecretSheetState();
}

class _ShareSecretSheetState extends ConsumerState<_ShareSecretSheet> {
  static const _log = AppLogger('ShareSecretSheet');

  static const _failed = 'Das hat nicht geklappt. Versuch es später nochmal.';

  final _sendKey = GlobalKey();
  bool _copied = false;
  bool _failedShown = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final origin = shareOriginOf(_sendKey.currentContext);
    final launcher = ref.read(shareLauncherProvider);
    try {
      await launcher(
        'Hier ist mein Belly Buddy Tagebuch: ${widget.secret.link}',
        origin,
      );
      if (mounted) setState(() => _failedShown = false);
    } catch (e, st) {
      _log.error('opening the share sheet failed', e, st);
      if (mounted) setState(() => _failedShown = true);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.secret.link));
    } catch (e, st) {
      _log.error('copying the link failed', e, st);
      if (mounted) setState(() => _failedShown = true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _copied = true;
      _failedShown = false;
    });
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
            widget.secret.link,
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
                  tapKey: _sendKey,
                  label: 'Link senden',
                  icon: Icons.ios_share,
                  onPressed: () => unawaited(_send()),
                ),
              ),
              const SizedBox(width: AppConstants.spacing12),
              Expanded(
                // A live region: the change to „Kopiert" is announced.
                child: Semantics(
                  key: shareCopiedLiveKey,
                  liveRegion: true,
                  child: BbButton(
                    label: _copied ? 'Kopiert' : 'Kopieren',
                    icon: _copied ? Icons.check : Icons.copy,
                    isOutlined: true,
                    onPressed: () => unawaited(_copy()),
                  ),
                ),
              ),
            ],
          ),
          if (_failedShown) ...[
            AppConstants.gap12,
            Semantics(
              liveRegion: true,
              child: const Text(
                _failed,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.destructive,
                ),
              ),
            ),
          ],
          AppConstants.gap24,
          Center(
            child: SelectableText(
              groupCode(widget.secret.code),
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
