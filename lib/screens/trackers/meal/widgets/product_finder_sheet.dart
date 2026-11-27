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
import '../../../../widgets/common/bb_sheet_messenger.dart';
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
        // A link that did not open says so in the sheet.
        builder: (_, scrollController) => BbSheetMessenger(
          child: SafeArea(
            top: false,
            child: ProductFinderSheet(
              scrollController: scrollController,
              openUrl: openUrl,
            ),
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

  static const searchFieldKey = ProductFinderKeys.search;
  static const applyKey = ProductFinderKeys.apply;
  static const otherProductKey = ProductFinderKeys.otherProduct;
  static const typeItKey = ProductFinderKeys.typeIt;
  static const offAddLinkKey = ProductFinderKeys.offAddLink;
  static const attributionKey = ProductFinderKeys.attribution;
  static const retryKey = ProductFinderKeys.retry;
  static const rescanKey = ProductFinderKeys.rescan;

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

  /// Why the camera could not start. A denied permission is cleared when
  /// the app comes back from the settings only: on Android every start
  /// asks again, and the permission dialog itself sends the app to the
  /// background and back. Any other failure is cleared on every return.
  ScannerFailure? _cameraFailure;

  /// „Einstellungen öffnen" was tapped since the camera failed.
  bool _openedSettings = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _searchFocus.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onLifecycle(AppLifecycleState s) {
    final resumed = s == AppLifecycleState.resumed;
    final clearFailure =
        resumed && (_openedSettings || _cameraFailure == ScannerFailure.other);
    if (resumed == _resumed && !clearFailure) return;
    setState(() {
      _resumed = resumed;
      if (clearFailure) {
        _cameraFailure = null;
        _openedSettings = false;
      }
    });
  }

  ProductFinderNotifier get _finder => ref.read(productFinderProvider.notifier);

  void _onBarcode(String barcode) {
    if (_finder.onBarcode(barcode)) HapticService.selection();
  }

  void _onFailure(ScannerFailure failure) =>
      setState(() => _cameraFailure = failure);

  /// „Nochmal scannen" in the scanner area: back to the camera; the field
  /// keeps its text.
  void _rescan() => _finder.reset();

  /// The way back from a product, not-found or failed lookup: to the hits
  /// it was picked from [from] (the field holds that term again), else
  /// scanning.
  void _back(SearchResults? from) {
    if (from != null) _query.text = from.query;
    _finder.back();
  }

  /// „Nochmal scannen", or „Zurück zur Suche" when the product came from
  /// [from].
  Widget _backButton(SearchResults? from) =>
      RescanButton(onTap: () => _back(from), toSearch: from != null);

  void _clearQuery() {
    _query.clear();
    // A pending or shown search of the cleared term goes too.
    if (ref.read(productFinderProvider)
        case SearchResults() || Searching() || Failed(search: true)) {
      _finder.reset();
    }
  }

  /// Only a settings page that opened clears a denied permission on the
  /// way back. Set before the open completes: the app may leave and come
  /// back before it does.
  Future<void> _openSettings() async {
    _openedSettings = true;
    final opened = await openAppSettings(context, open: widget.openUrl);
    if (!opened) _openedSettings = false;
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
            child: Text(
              'Produkt finden',
              style: productFinderHeading(AppTheme.fontSizeTitle),
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
              Scanning() ||
              Searching() ||
              SearchResults() ||
              Failed(search: true) => [
                _scannerArea(scanning: state is Scanning),
                AppConstants.gap16,
                ProductSearchField(
                  controller: _query,
                  focusNode: _searchFocus,
                  onSubmitted: _finder.search,
                  onClear: _clearQuery,
                ),
                AppConstants.gap16,
                if (state is Searching) const ProductFinderLoading(),
                if (state is SearchResults)
                  ProductSearchResults(hits: state.hits, onPick: _finder.pick),
                // „Nochmal scannen" is the scanner area's already.
                if (state is Failed)
                  ProductFailedView(
                    message: state.message,
                    // The field may have been edited since.
                    onRetry: () => _finder.retry(query: _query.text),
                  ),
              ],
              LookingUp() => [const ProductFinderLoading()],
              Found(:final product, :final from) => [
                ProductCard(
                  product: product,
                  onApply: () => Navigator.of(context).pop(product),
                  onOtherProduct: () => _back(from),
                  onAttribution: () => _open(
                    AppConstants.offProductUrl(product.barcode),
                    _pageFailed,
                  ),
                ),
              ],
              NotFound(:final barcode, :final from) => [
                ProductNotFoundView(
                  onTypeIt: () => Navigator.of(context).pop(),
                  onAddToOff: () => _open(
                    AppConstants.offAddProductUrl(barcode),
                    _pageFailed,
                  ),
                  rescan: _backButton(from),
                ),
              ],
              Failed(:final message, :final canRetry, :final from) => [
                ProductFailedView(
                  message: message,
                  onRetry: canRetry ? _finder.retry : null,
                  rescan: _backButton(from),
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
      return CameraProblemView(failure: failure, onOpenSettings: _openSettings);
    }
    if (!scanning) {
      return RescanButton(onTap: _rescan);
    }
    final scanner = ref.watch(barcodeScannerProvider);
    return ListenableBuilder(
      listenable: _searchFocus,
      builder: (context, _) => ScannerPreview(
        scanner: scanner(
          context,
          active: _resumed && !_searchFocus.hasFocus,
          onBarcode: _onBarcode,
          onFailure: _onFailure,
        ),
      ),
    );
  }
}
