import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/plus_status.dart';
import '../../providers/plus_provider.dart';
import '../../router/navigation_extensions.dart';
import '../../services/app_version_service.dart';
import '../../services/plus/plus_copy.dart';
import '../../services/purchases/purchases_gateway.dart';
import '../../utils/logger.dart';
import '../../utils/url_utils.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_card.dart';
import '../../widgets/common/mascot_image.dart';

const _log = AppLogger('PlusScreen');

/// The Belly Buddy Plus paywall (spec 4.5): what Plus brings, the store's
/// price, buy / restore, the store terms and links. With Plus (trial or
/// active) the status line and „Abo verwalten" replace the buy button.
///
/// The close button (top left) is always there, also while a purchase runs.
class PlusScreen extends ConsumerStatefulWidget {
  const PlusScreen({super.key, this.openUrl = launchUrl});

  static const buyKey = Key('plus_buy');
  static const restoreKey = Key('plus_restore');
  static const manageKey = Key('plus_manage');
  static const closeKey = Key('plus_close');
  static const termsKey = Key('plus_terms');
  static const privacyKey = Key('plus_privacy');

  /// Opens the links (`launchUrl`; tests record the launches).
  final UrlOpener openUrl;

  @override
  ConsumerState<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends ConsumerState<PlusScreen> {
  /// A purchase or restore is running: one at a time.
  bool _busy = false;

  void _close() => context.popOrGoDashboard();

  void _say(String message) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));

  /// Closes the paywall and welcomes the user (the messenger outlives it).
  void _welcome() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    _close();
    messenger?.showSnackBar(const SnackBar(content: Text(PlusCopy.welcome)));
  }

  /// Runs [run] unless a purchase or restore is already running; null when
  /// skipped or the paywall closed meanwhile.
  Future<PurchaseOutcome?> _once(
    Future<PurchaseOutcome> Function(PlusNotifier) run,
  ) async {
    if (_busy) return null;
    setState(() => _busy = true);
    final outcome = await run(ref.read(plusProvider.notifier));
    if (!mounted) return null;
    setState(() => _busy = false);
    return outcome;
  }

  Future<void> _buy(PlusOffer offer) async {
    final outcome = await _once((plus) => plus.purchase(offer));
    switch (outcome) {
      case null || PurchaseCancelled():
        break;
      case PurchaseDone():
        _welcome();
      case PurchasePending():
        _say(PlusCopy.pending);
      case PurchaseFailed():
        _say(PlusCopy.failed);
    }
  }

  Future<void> _restore() async {
    final outcome = await _once((plus) => plus.restore());
    switch (outcome) {
      case null || PurchaseCancelled():
        break;
      case PurchaseDone(:final status) when status.granted:
        _welcome();
      case PurchaseDone():
        _say(PlusCopy.restoreNone);
      case PurchasePending():
        _say(PlusCopy.pending);
      case PurchaseFailed():
        _say(PlusCopy.restoreFailed);
    }
  }

  Future<void> _open(String url) => openExternalUrl(
    context,
    url,
    failureMessage: PlusCopy.linkFailed,
    open: widget.openUrl,
  );

  /// The SDK's management page, else the platform store's subscriptions.
  Future<void> _manage(PlusStatus status) async {
    final managementUrl = status.managementUrl;
    if (managementUrl != null) return _open(managementUrl);
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _open(AppConstants.appleSubscriptionsUrl);
    }
    final String packageName;
    try {
      packageName = await ref.read(appVersionServiceProvider).packageName();
    } catch (e, st) {
      _log.error('package name unknown', e, st);
      if (mounted) _say(PlusCopy.linkFailed);
      return;
    }
    if (!mounted) return;
    await _open(
      AppConstants.playSubscriptionsUrl(
        AppConstants.playPlusProductId,
        packageName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(plusProvider);
    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: PlusScreen.closeKey,
          tooltip: PlusCopy.close,
          icon: const Icon(Icons.close, color: AppTheme.foreground),
          onPressed: _close,
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            0,
            AppConstants.spacingLg,
            AppConstants.spacingLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: MascotImage(
                  assetPath: AppConstants.mascotHappy,
                  width: AppConstants.mascotSizeMd,
                  height: AppConstants.mascotSizeMd,
                ),
              ),
              AppConstants.gap16,
              const Text(
                PlusCopy.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeHeadingLG,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
              AppConstants.gap24,
              const Text(
                PlusCopy.intro,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBodyLG,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
              AppConstants.gap12,
              for (final benefit in PlusCopy.benefits) _Benefit(benefit),
              AppConstants.gap12,
              const Text(
                PlusCopy.free,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.mutedForeground,
                ),
              ),
              AppConstants.gap24,
              BbCard(
                color: AppTheme.primarySoft,
                child: switch (status) {
                  AsyncData(value: final s) when s.granted => _plusBlock(s),
                  AsyncData() || AsyncError() => _offerBlock(),
                  _ => const _Loading(),
                },
              ),
              AppConstants.gap16,
              Text(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? PlusCopy.termsIos
                    : PlusCopy.termsAndroid,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeCaption,
                  color: AppTheme.mutedForeground,
                ),
              ),
              AppConstants.gap8,
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    key: PlusScreen.restoreKey,
                    onPressed: _busy ? null : _restore,
                    child: const Text(PlusCopy.restore),
                  ),
                  TextButton(
                    key: PlusScreen.termsKey,
                    onPressed: () => _open(AppConstants.termsUrl),
                    child: const Text(PlusCopy.terms),
                  ),
                  TextButton(
                    key: PlusScreen.privacyKey,
                    onPressed: () => _open(AppConstants.privacyPolicyUrl),
                    child: const Text(PlusCopy.privacy),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _offerBlock() {
    final offer = ref.watch(plusOfferProvider);
    return switch (offer) {
      AsyncData(value: final o?) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PlusCopy.priceLine(o.priceString, o.trialDays),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeSubtitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          AppConstants.gap12,
          BbButton(
            tapKey: PlusScreen.buyKey,
            label: PlusCopy.buyLabel(o.trialDays),
            isLoading: _busy,
            onPressed: () => _buy(o),
          ),
        ],
      ),
      AsyncData() || AsyncError() => const Text(
        PlusCopy.unavailable,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AppTheme.fontSizeBody,
          color: AppTheme.foreground,
        ),
      ),
      _ => const _Loading(),
    };
  }

  Widget _plusBlock(PlusStatus status) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        PlusCopy.statusLine(status),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeSubtitle,
          fontWeight: FontWeight.w600,
          color: AppTheme.foreground,
        ),
      ),
      AppConstants.gap12,
      BbButton(
        tapKey: PlusScreen.manageKey,
        label: PlusCopy.manage,
        isOutlined: true,
        onPressed: () => _manage(status),
      ),
    ],
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppTheme.primary,
          size: AppConstants.iconSizeSm,
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: Text(
            text,
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

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: AppConstants.paddingSm,
      child: CircularProgressIndicator(),
    ),
  );
}
