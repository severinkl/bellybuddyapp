import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../services/buddy/daily_care.dart';
import 'route_names.dart';

/// The tracker screen's path for logging [need].
String trackerPathFor(CareNeed need) => switch (need) {
  CareNeed.food => RoutePaths.mealTracker,
  CareNeed.drink => RoutePaths.drinkTracker,
  CareNeed.gutFeeling => RoutePaths.gutFeelingTracker,
  CareNeed.toilet => RoutePaths.toiletTracker,
};

/// Opens [need]'s tracker; [at] is the moment to log it at (null: now).
void openTracker(BuildContext context, CareNeed need, {DateTime? at}) {
  context.push(trackerPathFor(need), extra: at);
}
