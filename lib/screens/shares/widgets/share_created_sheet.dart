import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_bottom_sheet.dart';

/// Shows the [link] and [code] of a share as selectable text.
Future<void> showShareSecretSheet(
  BuildContext context, {
  required String link,
  required String code,
}) {
  return showBbBottomSheet<void>(
    context: context,
    builder: (_) => Padding(
      padding: AppConstants.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Link und Code',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppConstants.gap16,
          SelectableText(
            link,
            style: const TextStyle(fontSize: AppTheme.fontSizeBody),
          ),
          AppConstants.gap12,
          SelectableText(
            code,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeHeadingLG,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
