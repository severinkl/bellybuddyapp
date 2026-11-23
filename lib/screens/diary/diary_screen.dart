import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/diary_provider.dart';
import '../../services/haptic_service.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/page_controller_utils.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/common/mascot_image.dart';
import 'widgets/diary_detail_sheets.dart';
import 'widgets/diary_entry_card.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  static const previousDayKey = Key('diary_previous_day');
  static const nextDayKey = Key('diary_next_day');

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  static final DateTime _firstDate = DateTime(2020, 1, 1);
  late final PageController _controller;
  late final AppLifecycleListener _lifecycle;

  /// Today by the app's clock, and the pages up to it. The shell keeps the
  /// tab across midnight, so both move on with the clock ([_syncToday]).
  late DateTime _today;
  late int _pageCount;

  // DST-safe calendar math: Duration(days: n) is n*86400s, which drifts by
  // ±1h across DST boundaries. Over a multi-year span this rounds to the
  // wrong calendar day. Use DateTime(y, m, d+n) for additions and round
  // hour-differences for the inverse.
  int _indexFor(DateTime date) =>
      (startOfDay(date).difference(_firstDate).inHours / 24).round();

  DateTime _dateAt(int index) =>
      DateTime(_firstDate.year, _firstDate.month, _firstDate.day + index);

  @override
  void initState() {
    super.initState();
    _syncToday();
    _controller = PageController(
      initialPage: _indexFor(ref.read(diaryDateProvider)),
    );
    // Back in the app after midnight: the new today gets its page.
    _lifecycle = AppLifecycleListener(onResume: () => setState(_syncToday));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Sets [_today] (and the pages with it) to today by the app's clock.
  void _syncToday() {
    _today = startOfDay(ref.read(buddyClockProvider)());
    _pageCount = _indexFor(_today) + 1;
  }

  void _animateTo(DateTime date) => animatePageControllerTo(
    _controller,
    _indexFor(date),
    duration: AppConstants.animNormal,
  );

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(diaryDateProvider);
    // Any rebuild after midnight (a new day set, the resume) adds its page.
    _syncToday();
    final currentIndex = _indexFor(date);
    final isToday = isSameDay(date, _today);
    final isFirstDay = currentIndex <= 0;

    ref.listen<DateTime>(diaryDateProvider, (_, next) {
      if (_indexFor(next) < _pageCount) {
        _animateTo(next);
        return;
      }
      // Past the last page: a new today (midnight passed while the tab was
      // kept). The rebuild this change starts adds its page; go there then.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateTo(ref.read(diaryDateProvider));
      });
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: AppConstants.spacingMd,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isFirstDay)
              const SizedBox(width: AppConstants.iconBadgeMd)
            else
              CircleIconButton(
                tapKey: DiaryScreen.previousDayKey,
                icon: Icons.chevron_left,
                semanticLabel: 'Vorheriger Tag',
                onPressed: () {
                  HapticService.light();
                  ref
                      .read(diaryDateProvider.notifier)
                      .set(_dateAt(currentIndex - 1));
                },
              ),
            if (isToday)
              const SizedBox(width: AppConstants.iconBadgeMd)
            else
              CircleIconButton(
                tapKey: DiaryScreen.nextDayKey,
                icon: Icons.chevron_right,
                semanticLabel: 'Nächster Tag',
                onPressed: () {
                  HapticService.light();
                  ref
                      .read(diaryDateProvider.notifier)
                      .set(_dateAt(currentIndex + 1));
                },
              ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _pageCount,
        onPageChanged: (index) {
          HapticService.light();
          ref.read(diaryDateProvider.notifier).set(_dateAt(index));
        },
        itemBuilder: (context, index) =>
            _DiaryPage(date: _dateAt(index), today: _today),
      ),
    );
  }
}

class _DiaryPage extends ConsumerWidget {
  const _DiaryPage({required this.date, required this.today});

  final DateTime date;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: _DiaryScreenState._firstDate,
                lastDate: today,
                locale: const Locale('de', 'DE'),
              );
              if (picked != null) {
                HapticService.light();
                ref.read(diaryDateProvider.notifier).set(picked);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: AppTheme.mutedForeground,
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Flexible(
                  child: Text(
                    formatDateWeekday(date),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeSubtitle,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _DiaryBody(date: date, isToday: isSameDay(date, today)),
        ),
      ],
    );
  }
}

class _DiaryBody extends ConsumerWidget {
  const _DiaryBody({required this.date, required this.isToday});

  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(diaryEntriesProvider(date));

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async => ref.invalidate(diaryEntriesProvider(date)),
      child: entriesAsync.when(
        loading: () => const BbLoadingState(message: 'Einträge laden...'),
        error: (e, _) =>
            const BbErrorState(message: 'Fehler beim Laden der Einträge.'),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MascotImage(
                    assetPath: AppConstants.mascotHappy,
                    width: AppConstants.diaryEmptyBuddySize,
                    height: AppConstants.diaryEmptyBuddySize,
                  ),
                  AppConstants.gap16,
                  Text(
                    isToday
                        ? 'Noch keine Einträge für heute.'
                        : 'Keine Einträge an diesem Tag.',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeTitleLG,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  AppConstants.gap4,
                  const Text(
                    'Tipp unten aufs Plus, dann tragen wir was ein!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeSubtitle,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: AppConstants.paddingMd,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return DiaryEntryCard(
                entry: entry,
                onTap: () => showDiaryDetailSheet(context, ref, entry),
              );
            },
          );
        },
      ),
    );
  }
}
