import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/diary_provider.dart';
import '../utils/date_format_utils.dart';
import 'route_names.dart';

/// Switches to the Tagebuch tab, showing [day].
void openDiaryOn(BuildContext context, WidgetRef ref, DateTime day) {
  ref.read(diaryDateProvider.notifier).set(startOfDay(day));
  context.go(RoutePaths.diary);
}
