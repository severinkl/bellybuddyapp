import 'package:material_ui/material_ui.dart';

import '../../../../../config/app_theme.dart';
import '../../../../../config/constants.dart';
import '../../../../../models/product.dart';
import '../../../../../widgets/common/bb_button.dart';
import '../../../../../widgets/common/bb_ingredient_chip.dart';
import '../../../../../widgets/common/bb_sheet_row.dart';
import '../../../../../widgets/scanner/barcode_scanner.dart';
import '../../../../../widgets/scanner/scanner_scrim_label.dart';

// The pieces of the product sheet (product_finder_sheet.dart).

/// The keys the tests find the sheet's controls by.
abstract final class ProductFinderKeys {
  static const search = Key('productFinder.search');
  static const apply = Key('productFinder.apply');
  static const otherProduct = Key('productFinder.otherProduct');
  static const typeIt = Key('productFinder.typeIt');
  static const offAddLink = Key('productFinder.offAdd');
  static const attribution = Key('productFinder.attribution');
  static const retry = Key('productFinder.retry');
  static const rescan = Key('productFinder.rescan');
}

/// Semibold text in the foreground colour, of [size].
TextStyle productFinderHeading(double size) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: AppTheme.foreground,
);

final _titleStyle = productFinderHeading(AppTheme.fontSizeSubtitle);

const _bodyStyle = TextStyle(
  fontSize: AppTheme.fontSizeBody,
  color: AppTheme.mutedForeground,
  height: AppTheme.lineHeightBody,
);

/// Body text in the foreground colour (a message that must stand out).
final _messageStyle = _bodyStyle.copyWith(color: AppTheme.foreground);

const _captionStyle = TextStyle(
  fontSize: AppTheme.fontSizeCaption,
  color: AppTheme.mutedForeground,
);

/// A white card on the sheet.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppConstants.paddingMd,
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      border: Border.all(
        color: AppTheme.border,
        width: AppConstants.borderWidthSm,
      ),
    ),
    child: child,
  );
}

/// The live camera with a frame and the hint on the scrim.
class ScannerPreview extends StatelessWidget {
  const ScannerPreview({super.key, required this.scanner});

  final Widget scanner;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppConstants.radiusXl),
    child: AspectRatio(
      aspectRatio: AppConstants.scannerAspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black, child: scanner),
          IgnorePointer(
            child: Padding(
              padding: AppConstants.scanFrameInset,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: AppConstants.borderWidthLg,
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
            ),
          ),
          const Positioned(
            left: AppConstants.spacingMd,
            right: AppConstants.spacingMd,
            bottom: AppConstants.spacingSm,
            child: IgnorePointer(
              child: ScannerScrimLabel('Halte den Barcode in den Rahmen'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// In place of the camera when it cannot run: why, and for a missing
/// permission the way to the settings.
class CameraProblemView extends StatelessWidget {
  const CameraProblemView({
    super.key,
    required this.failure,
    required this.onOpenSettings,
  });

  final ScannerFailure failure;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => _Panel(
    child: switch (failure) {
      ScannerFailure.permissionDenied => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kein Zugriff auf die Kamera', style: _titleStyle),
          AppConstants.gap8,
          const Text(
            'Erlaube Belly Buddy in den Einstellungen den Zugriff auf die '
            'Kamera, um Barcodes zu scannen. Du kannst das Produkt auch '
            'unten suchen.',
            style: _bodyStyle,
          ),
          AppConstants.gap8,
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Einstellungen öffnen'),
          ),
        ],
      ),
      ScannerFailure.other => const Text(
        'Die Kamera konnte nicht gestartet werden. Du kannst das Produkt '
        'auch unten suchen.',
        style: _bodyStyle,
      ),
    },
  );
}

/// „Nochmal scannen": back to the camera; „Zurück zur Suche" with
/// [toSearch] (the product was picked from search hits).
class RescanButton extends StatelessWidget {
  const RescanButton({super.key, required this.onTap, this.toSearch = false});

  final VoidCallback onTap;
  final bool toSearch;

  @override
  Widget build(BuildContext context) => BbButton(
    tapKey: ProductFinderKeys.rescan,
    label: toSearch ? 'Zurück zur Suche' : 'Nochmal scannen',
    icon: toSearch ? Icons.search : Icons.qr_code_scanner,
    isOutlined: true,
    onPressed: onTap,
  );
}

/// The search field; a search runs on submit only.
class ProductSearchField extends StatelessWidget {
  const ProductSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final pillBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      borderSide: BorderSide.none,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        key: ProductFinderKeys.search,
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Produkt oder Marke suchen',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Suche löschen',
                  onPressed: onClear,
                ),
          filled: true,
          fillColor: AppTheme.background,
          border: pillBorder,
          enabledBorder: pillBorder,
          focusedBorder: pillBorder,
        ),
      ),
    );
  }
}

/// The spinner while a search or lookup runs.
class ProductFinderLoading extends StatelessWidget {
  const ProductFinderLoading({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXl),
    child: Column(
      children: [
        const CircularProgressIndicator(),
        AppConstants.gap12,
        Semantics(
          liveRegion: true,
          child: const Text('Suche Produkt …', style: _bodyStyle),
        ),
      ],
    ),
  );
}

/// The hits, or the text that there are none.
class ProductSearchResults extends StatelessWidget {
  const ProductSearchResults({
    super.key,
    required this.hits,
    required this.onPick,
  });

  final List<ProductHit> hits;
  final ValueChanged<ProductHit> onPick;

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppConstants.spacingSm),
        child: Text(
          'Keine Produkte gefunden. Versuch einen anderen Namen oder trag '
          'die Mahlzeit selbst ein.',
          textAlign: TextAlign.center,
          style: _bodyStyle,
        ),
      );
    }
    return Column(
      children: [
        for (final (i, hit) in hits.indexed) ...[
          if (i > 0) AppConstants.gap8,
          BbSheetRow(
            onTap: () => onPick(hit),
            leading: Container(
              width: AppConstants.iconBadgeSm,
              height: AppConstants.iconBadgeSm,
              decoration: BoxDecoration(
                color: AppTheme.muted,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.shopping_basket_outlined,
                color: AppTheme.mutedForeground,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hit.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: productFinderHeading(AppTheme.fontSizeBody),
                ),
                if (hit.brand case final brand?)
                  Text(
                    brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _captionStyle,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The found product: name, brand, ingredients, attribution and the two
/// ways on.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onApply,
    required this.onOtherProduct,
    required this.onAttribution,
  });

  final ProductPrefill product;
  final VoidCallback onApply;
  final VoidCallback onOtherProduct;
  final VoidCallback onAttribution;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.title,
              style: productFinderHeading(AppTheme.fontSizeTitle),
            ),
            if (product.brand case final brand?) ...[
              AppConstants.gap4,
              Text(brand, style: _bodyStyle),
            ],
            AppConstants.gap12,
            if (product.ingredients.isEmpty)
              const Text(
                'Für dieses Produkt sind keine Zutaten hinterlegt. Du kannst '
                'sie gleich selbst eintragen.',
                style: _bodyStyle,
              )
            else
              Wrap(
                spacing: AppConstants.spacingXs,
                runSpacing: AppConstants.spacingXs,
                children: [
                  for (final ingredient in product.ingredients)
                    BbIngredientChip(label: ingredient.name),
                ],
              ),
            AppConstants.gap8,
            Semantics(
              link: true,
              child: TextButton(
                key: ProductFinderKeys.attribution,
                onPressed: onAttribution,
                child: const Text(
                  'Produktdaten: Open Food Facts (ODbL)',
                  style: TextStyle(fontSize: AppTheme.fontSizeCaption),
                ),
              ),
            ),
          ],
        ),
      ),
      AppConstants.gap16,
      BbButton(
        tapKey: ProductFinderKeys.apply,
        label: 'Übernehmen',
        onPressed: onApply,
      ),
      AppConstants.gap8,
      BbButton(
        tapKey: ProductFinderKeys.otherProduct,
        label: 'Anderes Produkt',
        isOutlined: true,
        onPressed: onOtherProduct,
      ),
    ],
  );
}

/// Core doesn't know the code: enter the meal by hand, add the product to
/// Open Food Facts, or go [rescan] (the sheet's back button).
class ProductNotFoundView extends StatelessWidget {
  const ProductNotFoundView({
    super.key,
    required this.onTypeIt,
    required this.onAddToOff,
    required this.rescan,
  });

  final VoidCallback onTypeIt;
  final VoidCallback onAddToOff;
  final Widget rescan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dieses Produkt kennen wir noch nicht.', style: _titleStyle),
            AppConstants.gap8,
            const Text(
              'Du kannst die Mahlzeit einfach selbst eintragen.',
              style: _bodyStyle,
            ),
          ],
        ),
      ),
      AppConstants.gap16,
      BbButton(
        tapKey: ProductFinderKeys.typeIt,
        label: 'Selbst eintragen',
        onPressed: onTypeIt,
      ),
      AppConstants.gap8,
      rescan,
      AppConstants.gap8,
      Semantics(
        link: true,
        child: TextButton(
          key: ProductFinderKeys.offAddLink,
          onPressed: onAddToOff,
          child: const Text(
            'Produkt bei Open Food Facts ergänzen',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ],
  );
}

/// A call failed: the message, maybe „Nochmal versuchen" and maybe
/// the sheet's back button ([rescan]).
class ProductFailedView extends StatelessWidget {
  const ProductFailedView({
    super.key,
    required this.message,
    required this.onRetry,
    this.rescan,
  });

  final String message;

  /// „Nochmal versuchen", unless null (repeating cannot help).
  final VoidCallback? onRetry;

  /// The back button below the retry, unless null.
  final Widget? rescan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Panel(
        child: Semantics(
          liveRegion: true,
          child: Text(message, style: _messageStyle),
        ),
      ),
      if (onRetry case final onRetry?) ...[
        AppConstants.gap16,
        BbButton(
          tapKey: ProductFinderKeys.retry,
          label: 'Nochmal versuchen',
          onPressed: onRetry,
        ),
      ],
      if (rescan case final rescan?) ...[AppConstants.gap8, rescan],
    ],
  );
}
