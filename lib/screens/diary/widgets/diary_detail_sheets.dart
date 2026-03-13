import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../models/meal_entry.dart';
import '../../../models/toilet_entry.dart';
import '../../../models/gut_feeling_entry.dart';
import '../../../models/drink_entry.dart';
import '../../../providers/diary_provider.dart';
import '../../../utils/gut_feeling_rating.dart';
import '../../../utils/signed_url_helper.dart';

void showDiaryDetailSheet(BuildContext context, WidgetRef ref, DiaryEntry entry) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: _buildContent(context, ref, entry),
          );
        },
      );
    },
  );
}

Widget _buildContent(BuildContext context, WidgetRef ref, DiaryEntry entry) {
  final dateFormat = DateFormat('EEEE, dd.MM.yyyy HH:mm', 'de_DE');
  final formattedDate = '${dateFormat.format(entry.trackedAt)} Uhr';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.muted,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        entry.title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        formattedDate,
        style: const TextStyle(fontSize: 14, color: AppTheme.mutedForeground),
      ),
      const SizedBox(height: 24),
      _buildTypeSpecificContent(entry),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () async {
            Navigator.pop(context);
            await deleteEntry(entry.type, entry.id);
            final date = ref.read(diaryDateProvider);
            ref.invalidate(diaryEntriesProvider(date));
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.destructive,
            side: const BorderSide(color: AppTheme.destructive),
          ),
          child: const Text('Eintrag löschen'),
        ),
      ),
    ],
  );
}

Widget _buildTypeSpecificContent(DiaryEntry entry) {
  switch (entry.type) {
    case DiaryEntryType.meal:
      final meal = entry.data as MealEntry;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meal.imageUrl != null)
            _MealImage(imageUrl: meal.imageUrl!),
          if (meal.ingredients.isNotEmpty) ...[
            const Text(
              'Zutaten',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: meal.ingredients.map((i) => Chip(label: Text(i))).toList(),
            ),
          ],
          if (meal.notes != null) ...[
            const SizedBox(height: 16),
            Text(meal.notes!, style: const TextStyle(color: AppTheme.mutedForeground)),
          ],
        ],
      );

    case DiaryEntryType.toilet:
      final toilet = entry.data as ToiletEntry;
      final descriptions = {1: 'Sehr hart', 2: 'Hart', 3: 'Normal', 4: 'Weich', 5: 'Flüssig'};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Konsistenz: ${descriptions[toilet.stoolType] ?? 'Normal'}',
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            'Stufe ${toilet.stoolType} von 5',
            style: const TextStyle(color: AppTheme.mutedForeground),
          ),
        ],
      );

    case DiaryEntryType.gutFeeling:
      final gut = entry.data as GutFeelingEntry;
      final rating = calculateGutFeelingRating(gut);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: rating.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              rating.level.label,
              style: TextStyle(
                color: rating.color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _detailRow('Blähbauch', gut.bloating),
          _detailRow('Blähungen', gut.gas),
          _detailRow('Krämpfe', gut.cramps),
          _detailRow('Völlegefühl', gut.fullness),
          if (gut.stress != null) _detailRow('Stress', gut.stress!),
          if (gut.happiness != null) _detailRow('Glück', gut.happiness!),
          if (gut.energy != null) _detailRow('Energie', gut.energy!),
          if (gut.focus != null) _detailRow('Fokus', gut.focus!),
          if (gut.bodyFeel != null) _detailRow('Körpergefühl', gut.bodyFeel!),
        ],
      );

    case DiaryEntryType.drink:
      final drink = entry.data as DrinkEntry;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${drink.amountMl} ml',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (drink.notes != null) ...[
            const SizedBox(height: 8),
            Text(drink.notes!, style: const TextStyle(color: AppTheme.mutedForeground)),
          ],
        ],
      );
  }
}

Widget _detailRow(String label, int value) {
  final color = getValueColor(value);
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15)),
        Text(
          '$value / 5',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Stateful widget that resolves a signed URL for a meal image.
class _MealImage extends StatefulWidget {
  final String imageUrl;
  const _MealImage({required this.imageUrl});

  @override
  State<_MealImage> createState() => _MealImageState();
}

class _MealImageState extends State<_MealImage> {
  String? _resolvedUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final url = await resolveSignedMealImageUrl(widget.imageUrl);
    if (mounted) {
      setState(() {
        _resolvedUrl = url;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.muted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_resolvedUrl == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: _resolvedUrl!,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            height: 180,
            color: AppTheme.muted,
          ),
          errorWidget: (_, __, ___) => Container(
            height: 180,
            color: AppTheme.muted,
            child: const Center(
              child: Icon(Icons.image_not_supported, color: AppTheme.mutedForeground),
            ),
          ),
        ),
      ),
    );
  }
}
