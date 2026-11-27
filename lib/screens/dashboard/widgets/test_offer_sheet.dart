import 'package:material_ui/material_ui.dart';

import '../../../models/tolerance_test.dart';
import '../../../services/insights/test_copy.dart';
import '../../../widgets/buddy/buddy_ask_sheet.dart';

/// The Buddy's offer of a Verträglichkeits-Test of [subject]
/// ([TestOfferSheet], spec §5.5), over the bottom bar. True for „Ansehen";
/// false for „Später" or when dismissed.
Future<bool> showTestOfferSheet(
  BuildContext context, {
  required TestSubject subject,
}) async =>
    await showBuddySheet<bool>(
      context,
      builder: (_) => TestOfferSheet(subject: subject),
    ) ??
    false;

/// The Buddy asks whether to test [subject] ([TestCopy.offerTitle]); the
/// body says why and how long; „Ansehen" pops true, „Später" false.
class TestOfferSheet extends StatelessWidget {
  const TestOfferSheet({super.key, required this.subject});

  final TestSubject subject;

  static const openKey = Key('test_offer_open');
  static const laterKey = Key('test_offer_later');

  @override
  Widget build(BuildContext context) {
    return BuddyAskSheet(
      line: TestCopy.offerTitle,
      actions: BuddySheetActions(
        primaryKey: openKey,
        primary: TestCopy.offerOpen,
        onPrimary: () => Navigator.pop(context, true),
        secondaryKey: laterKey,
        secondary: TestCopy.offerLater,
        onSecondary: () => Navigator.pop(context, false),
      ),
      child: BuddySheetText(TestCopy.offerBody(subject)),
    );
  }
}
