import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../utils/title_color.dart';
import 'signed_path_image.dart';

/// 56×56 thumbnail with rounded corners. Renders [imageUrl] when present;
/// otherwise a deterministic pastel background (per [title]) with a faded
/// book-icon glyph.
class BbPastelThumb extends StatelessWidget {
  const BbPastelThumb({super.key, required this.title, this.imageUrl});

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return SizedBox(
        width: AppConstants.iconBadgeXl,
        height: AppConstants.iconBadgeXl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: SignedPathImage(
            pathOrUrl: imageUrl,
            width: AppConstants.iconBadgeXl,
            height: AppConstants.iconBadgeXl,
            placeholder: Container(color: AppTheme.muted),
            errorWidget: _placeholder(),
          ),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: AppConstants.iconBadgeXl,
      height: AppConstants.iconBadgeXl,
      decoration: BoxDecoration(
        color: pastelForTitle(title),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_outlined,
        color: AppTheme.foreground.withValues(alpha: 0.45),
        size: AppConstants.iconSizeMd,
      ),
    );
  }
}
