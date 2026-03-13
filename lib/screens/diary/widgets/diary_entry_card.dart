import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/meal_entry.dart';
import '../../../models/gut_feeling_entry.dart';
import '../../../providers/diary_provider.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/gut_feeling_rating.dart';
import '../../../utils/signed_url_helper.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/mascot_image.dart';

String mascotForRating(GutFeelingRatingLevel level) => switch (level) {
      GutFeelingRatingLevel.spiGut => AppConstants.mascotCool,
      GutFeelingRatingLevel.gut => AppConstants.mascotHappy,
      GutFeelingRatingLevel.durchschnittlich => AppConstants.mascotEnergetic,
      GutFeelingRatingLevel.schlecht => AppConstants.mascotSad,
    };

class DiaryEntryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const DiaryEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDismissed,
  });

  Color get _color => switch (entry.type) {
        DiaryEntryType.meal => AppTheme.primary,
        DiaryEntryType.toilet => AppTheme.info,
        DiaryEntryType.gutFeeling => AppTheme.warning,
        DiaryEntryType.drink => AppTheme.success,
      };

  Widget get _leadingWidget {
    if (entry.type == DiaryEntryType.meal) {
      final meal = entry.data as MealEntry;
      if (meal.imageUrl != null) {
        return MealThumbnail(imageUrl: meal.imageUrl!);
      }
    }
    if (entry.type == DiaryEntryType.gutFeeling) {
      final gut = entry.data as GutFeelingEntry;
      final rating = calculateGutFeelingRating(gut);
      return MascotImage(
        assetPath: mascotForRating(rating.level),
        width: 40,
        height: 40,
      );
    }
    if (entry.type == DiaryEntryType.toilet) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: SvgPicture.asset(
            AppConstants.toiletPaperSvg,
            width: 22,
            height: 22,
          ),
        ),
      );
    }
    final icon = switch (entry.type) {
      DiaryEntryType.meal => Icons.restaurant,
      DiaryEntryType.toilet => Icons.wc,
      DiaryEntryType.gutFeeling => Icons.favorite,
      DiaryEntryType.drink => Icons.local_drink,
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: _color, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(entry.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          HapticService.medium();
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Eintrag löschen?'),
              content: const Text('Möchtest du diesen Eintrag wirklich löschen?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
                  child: const Text('Löschen'),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) => onDismissed(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.destructive,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: BbCard(
            child: Row(
              children: [
                _leadingWidget,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                      Text(
                        entry.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatTime(entry.trackedAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MealThumbnail extends StatefulWidget {
  final String imageUrl;
  const MealThumbnail({super.key, required this.imageUrl});

  @override
  State<MealThumbnail> createState() => _MealThumbnailState();
}

class _MealThumbnailState extends State<MealThumbnail> {
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final url = await resolveSignedMealImageUrl(widget.imageUrl);
    if (mounted) setState(() => _resolvedUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedUrl == null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.restaurant, color: AppTheme.primary, size: 20),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: _resolvedUrl!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        errorWidget: (_, _, _) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.restaurant, color: AppTheme.primary, size: 20),
        ),
      ),
    );
  }
}
