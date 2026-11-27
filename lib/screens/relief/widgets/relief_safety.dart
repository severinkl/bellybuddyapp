import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../services/relief/relief_content.dart';
import '../../../utils/url_utils.dart';

/// „Das ersetzt keine ärztliche Hilfe. …" with an info icon; a tap opens
/// [showReliefSafetySheet]. Inset by [AppConstants.spacingMd] on both sides.
class ReliefSafetyLine extends StatelessWidget {
  const ReliefSafetyLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
      child: _line(context),
    );
  }

  Widget _line(BuildContext context) {
    return InkWell(
      onTap: () => showReliefSafetySheet(context),
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppConstants.minTapTarget),
        child: const Padding(
          padding: AppConstants.paddingSm,
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: AppConstants.iconSizeSm,
                color: AppTheme.mutedForeground,
              ),
              SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Text(
                  ReliefCopy.safetyLine,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeCaption,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// „Wann du Hilfe holen solltest": static text, each number a button that
/// opens the dialer with [open]. When the dialer cannot open, the sheet
/// closes and a SnackBar says to dial the number directly.
Future<void> showReliefSafetySheet(
  BuildContext context, {
  UrlOpener open = launchUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _SafetySheet(open: open),
  );
}

class _SafetySheet extends StatelessWidget {
  const _SafetySheet({required this.open});

  final UrlOpener open;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(
      fontSize: AppTheme.fontSizeBody,
      color: AppTheme.foreground,
    );
    const heading = TextStyle(
      fontSize: AppTheme.fontSizeSubtitle,
      fontWeight: FontWeight.w600,
      color: AppTheme.foreground,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppConstants.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: const Text(
                ReliefCopy.safetySheetTitle,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeTitleLG,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foreground,
                ),
              ),
            ),
            AppConstants.gap12,
            const Text(ReliefCopy.safetyIntro, style: body),
            AppConstants.gap16,
            const Text(ReliefCopy.emergencyHeading, style: heading),
            AppConstants.gap4,
            for (final item in ReliefCopy.emergencyItems)
              _Bullet(item, style: body),
            AppConstants.gap16,
            const Text(ReliefCopy.soonHeading, style: heading),
            AppConstants.gap4,
            for (final item in ReliefCopy.soonItems) _Bullet(item, style: body),
            AppConstants.gap20,
            const Text(ReliefCopy.emergencyRowLabel, style: heading),
            for (final dial in ReliefCopy.emergencyDials)
              _DialRow(dial: dial, open: open),
            AppConstants.gap12,
            const Text(ReliefCopy.adviceRowLabel, style: heading),
            for (final dial in ReliefCopy.adviceDials)
              _DialRow(dial: dial, open: open),
            AppConstants.gap4,
            const Text(ReliefCopy.adviceSwitzerland, style: body),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Text('•  ', style: style)),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

class _DialRow extends StatelessWidget {
  const _DialRow({required this.dial, required this.open});

  final ReliefDial dial;
  final UrlOpener open;

  Future<void> _dial(BuildContext context) async {
    final opened = await openExternalUrl(
      context,
      Uri(scheme: 'tel', path: dial.number.replaceAll(' ', '')).toString(),
      failureMessage: ReliefCopy.dialFailed(dial.number),
      open: open,
    );
    // The SnackBar shows under the sheet; close it so the number is seen.
    if (!opened && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingSm),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => _dial(context),
            style: OutlinedButton.styleFrom(
              minimumSize: AppConstants.minTapSize,
            ),
            icon: const Icon(Icons.phone, size: AppConstants.iconSizeSm),
            label: Text(dial.number),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              dial.caption,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
