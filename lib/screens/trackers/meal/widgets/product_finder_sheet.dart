import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../models/product.dart';
import '../../../../providers/product_finder_provider.dart';
import '../../../../services/haptic_service.dart';
import '../../../../utils/url_utils.dart';
import '../../../../widgets/common/bb_drag_handle.dart';
import '../../../../widgets/scanner/barcode_scanner.dart';
import 'product_finder/product_finder_parts.dart';

/// Opens the product sheet: scan a barcode or search a product. Resolves
/// with the product the user takes („Übernehmen"), or null when dismissed
/// or „Selbst eintragen". Links open with [openUrl].
Future<ProductPrefill?> showProductFinderSheet(
  BuildContext context, {
  UrlOpener openUrl = launchUrl,
}) {
  return showModalBottomSheet<ProductPrefill>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    // The sheet draws its own handle.
    showDragHandle: false,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusXl),
      ),
    ),
    builder: (sheetCtx) => Padding(
      // Above the soft keyboard: padding outside the draggable shrinks it.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => SafeArea(
          top: false,
          child: ProductFinderSheet(
            scrollController: scrollController,
            openUrl: openUrl,
          ),
        ),
      ),
    ),
  );
}

/// The sheet's body ([showProductFinderSheet]). The camera runs only while
/// scanning, the search field has no focus and the app is in front.
class ProductFinderSheet extends ConsumerStatefulWidget {
  const ProductFinderSheet({
    super.key,
    required this.scrollController,
    required this.openUrl,
  });

  static const searchFieldKey = Key('productFinder.search');
  static const applyKey = Key('productFinder.apply');
  static const otherProductKey = Key('productFinder.otherProduct');
  static const typeItKey = Key('productFinder.typeIt');
  static const offAddLinkKey = Key('productFinder.offAdd');
  static const attributionKey = Key('productFinder.attribution');
  static const retryKey = Key('productFinder.retry');
  static const rescanKey = Key('productFinder.rescan');

  final ScrollController scrollController;
  final UrlOpener openUrl;

  @override
  ConsumerState<ProductFinderSheet> createState() => _ProductFinderSheetState();
}

class _ProductFinderSheetState extends ConsumerState<ProductFinderSheet> {
  final _query = TextEditingController();
  final _searchFocus = FocusNode();
  late final AppLifecycleListener _lifecycle;

  /// The app is in front (null: not reported yet, as in tests).
  bool _resumed = switch (WidgetsBinding.instance.lifecycleState) {
    null || AppLifecycleState.resumed => true,
    _ => false,
  };

  /// Why the camera could not start; cleared when the app comes back to
  /// the front (the user may have allowed it in the settings meanwhile).
  ScannerFailure? _cameraFailure;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_rebuild);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _searchFocus.dispose();
    _query.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _onLifecycle(AppLifecycleState s) => setState(() {
    _resumed = s == AppLifecycleState.resumed;
    if (_resumed) _cameraFailure = null;
  });

  ProductFinderNotifier get _finder => ref.read(productFinderProvider.notifier);

  void _onBarcode(String barcode) {
    if (_finder.onBarcode(barcode)) HapticService.selection();
  }

  void _onFailure(ScannerFailure failure) =>
      setState(() => _cameraFailure = failure);

  void _rescan() {
    _query.clear();
    _finder.reset();
  }

  void _clearQuery() {
    _query.clear();
    if (ref.read(productFinderProvider) is SearchResults) _finder.reset();
  }

  Future<void> _open(String url, String failureMessage) => openExternalUrl(
    context,
    url,
    failureMessage: failureMessage,
    open: widget.openUrl,
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productFinderProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppConstants.spacingSm),
        const BbDragHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            AppConstants.spacingMd,
            AppConstants.spacingLg,
            AppConstants.spacingSm,
          ),
          child: Semantics(
            header: true,
            child: const Text(
              'Produkt finden',
              style: TextStyle(
                fontSize: AppTheme.fontSizeTitle,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingMd,
              AppConstants.spacingSm,
              AppConstants.spacingMd,
              AppConstants.spacingMd,
            ),
            children: switch (state) {
              Scanning() || Searching() || SearchResults() => [
                _scannerArea(scanning: state is Scanning),
                AppConstants.gap16,
                ProductSearchField(
                  fieldKey: ProductFinderSheet.searchFieldKey,
                  controller: _query,
                  focusNode: _searchFocus,
                  onSubmitted: _finder.search,
                  onClear: _clearQuery,
                ),
                AppConstants.gap16,
                if (state is Searching) const ProductFinderLoading(),
                if (state is SearchResults)
                  ProductSearchResults(hits: state.hits, onPick: _finder.pick),
              ],
              LookingUp() => [const ProductFinderLoading()],
              Found(:final product) => [
                ProductCard(
                  product: product,
                  applyKey: ProductFinderSheet.applyKey,
                  otherProductKey: ProductFinderSheet.otherProductKey,
                  attributionKey: ProductFinderSheet.attributionKey,
                  onApply: () => Navigator.of(context).pop(product),
                  onOtherProduct: _rescan,
                  onAttribution: () => _open(
                    AppConstants.offProductUrl(product.barcode),
                    _pageFailed,
                  ),
                ),
              ],
              NotFound(:final barcode) => [
                ProductNotFoundView(
                  typeItKey: ProductFinderSheet.typeItKey,
                  offAddLinkKey: ProductFinderSheet.offAddLinkKey,
                  rescanKey: ProductFinderSheet.rescanKey,
                  onTypeIt: () => Navigator.of(context).pop(),
                  onAddToOff: () => _open(
                    AppConstants.offAddProductUrl(barcode),
                    _pageFailed,
                  ),
                  onRescan: _rescan,
                ),
              ],
              Failed(:final message) => [
                ProductFailedView(
                  message: message,
                  retryKey: ProductFinderSheet.retryKey,
                  rescanKey: ProductFinderSheet.rescanKey,
                  onRetry: _finder.retry,
                  onRescan: _rescan,
                ),
              ],
            },
          ),
        ),
      ],
    );
  }

  static const _pageFailed = 'Die Seite konnte nicht geöffnet werden.';

  Widget _scannerArea({required bool scanning}) {
    final failure = _cameraFailure;
    if (failure != null) {
      return CameraProblemView(
        failure: failure,
        onOpenSettings: () => _open(
          appSettingsUrl,
          'Die Einstellungen konnten nicht geöffnet werden.',
        ),
      );
    }
    if (!scanning) {
      return RescanButton(tapKey: ProductFinderSheet.rescanKey, onTap: _rescan);
    }
    final scanner = ref.watch(barcodeScannerProvider);
    return ScannerPreview(
      scanner: scanner(
        context,
        active: _resumed && !_searchFocus.hasFocus,
        onBarcode: _onBarcode,
        onFailure: _onFailure,
      ),
    );
  }
}
