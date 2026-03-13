import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/entries_provider.dart';
import '../../providers/profile_provider.dart';
import '../../router/route_names.dart';
import '../../widgets/common/bb_card.dart';
import '../../widgets/common/mascot_image.dart';
import '../../widgets/common/press_scale_wrapper.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await ref.read(profileProvider.notifier).fetchProfile();
    await ref.read(entriesProvider.notifier).loadEntries(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with greeting
                _DashboardHeader(),
                const SizedBox(height: 24),
                // Tracker cards
                _TrackerCards(),
                const SizedBox(height: 32),
                // For You section
                _ForYouSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Guten Morgen'
        : hour < 18
            ? 'Guten Tag'
            : 'Guten Abend';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Wie geht es deinem Bauch heute?',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const MascotImage(
          assetPath: AppConstants.susiPhone,
          width: 72,
          height: 72,
        ),
      ],
    );
  }
}

class _TrackerCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Schnell tracken',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _TrackerCard(
              icon: Icons.restaurant,
              label: 'Mahlzeit',
              color: AppTheme.primary,
              onTap: () => context.push(RoutePaths.mealTracker),
            ),
            _TrackerCard(
              icon: Icons.wc,
              label: 'Toilette',
              color: AppTheme.info,
              onTap: () => context.push(RoutePaths.toiletTracker),
            ),
            _TrackerCard(
              icon: Icons.favorite,
              label: 'Stimmung',
              color: AppTheme.warning,
              onTap: () => context.push(RoutePaths.gutFeelingTracker),
            ),
            _TrackerCard(
              icon: Icons.local_drink,
              label: 'Getränke',
              color: AppTheme.success,
              onTap: () => context.push(RoutePaths.drinkTracker),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrackerCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TrackerCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScaleWrapper(
      onTap: onTap,
      child: BbCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForYouSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Für dich',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 12),
        PressScaleWrapper(
          onTap: () => context.push(RoutePaths.recommendations),
          child: BbCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lightbulb_outline, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Empfehlungen',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                      Text(
                        'Personalisierte Tipps für dich',
                        style: TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        PressScaleWrapper(
          onTap: () => context.push(RoutePaths.ingredientSuggestions),
          child: BbCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.search, color: AppTheme.warning),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zutaten-Vorschläge',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                      Text(
                        'Problematische Zutaten erkennen',
                        style: TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        PressScaleWrapper(
          onTap: () => context.push(RoutePaths.recipes),
          child: BbCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book, color: AppTheme.success),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rezepte',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                      Text(
                        'Verträgliche Rezepte entdecken',
                        style: TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
