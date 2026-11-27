import 'package:material_ui/material_ui.dart';

import '../../../../../config/app_theme.dart';
import '../../../../../config/constants.dart';
import '../../../../../models/product.dart';
import '../../../../../widgets/common/bb_button.dart';
import '../../../../../widgets/common/bb_ingredient_chip.dart';
import '../../../../../widgets/common/bb_sheet_row.dart';
import '../../../../../widgets/scanner/barcode_scanner.dart';

// The pieces of the product sheet (product_finder_sheet.dart).

const _titleStyle = TextStyle(
  fontSize: AppTheme.fontSizeSubtitle,
  fontWeight: FontWeight.w600,
  color: AppTheme.foreground,
);

const _bodyStyle = TextStyle(
  fontSize: AppTheme.fontSizeBody,
  color: AppTheme.mutedForeground,
  height: AppTheme.lineHeightBody,
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
              // On the scrim: white text stays readable over any picture.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.scrim,
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppConstants.radiusMd),
                  ),
                ),
                child: Padding(
                  padding: AppConstants.paddingSm,
                  child: Text(
                    'Halte den Barcode in den Rahmen',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
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
          const Text('Kein Zugriff auf die Kamera', style: _titleStyle),
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

/// „Nochmal scannen": back to the camera.
class RescanButton extends StatelessWidget {
  const RescanButton({super.key, required this.tapKey, required this.onTap});

  final Key tapKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BbButton(
    tapKey: tapKey,
    label: 'Nochmal scannen',
    icon: Icons.qr_code_scanner,
    isOutlined: true,
    onPressed: onTap,
  );
}

/// The search field; a search runs on submit only.
class ProductSearchField extends StatelessWidget {
  const ProductSearchField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
  });

  final Key fieldKey;
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
        key: fieldKey,
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
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                if (hit.brand case final brand?)
                  Text(
                    brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeCaption,
                      color: AppTheme.mutedForeground,
                    ),
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
    required this.applyKey,
    required this.otherProductKey,
    required this.attributionKey,
    required this.onApply,
    required this.onOtherProduct,
    required this.onAttribution,
  });

  final ProductPrefill product;
  final Key applyKey;
  final Key otherProductKey;
  final Key attributionKey;
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
              style: const TextStyle(
                fontSize: AppTheme.fontSizeTitle,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
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
                key: attributionKey,
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
      BbButton(tapKey: applyKey, label: 'Übernehmen', onPressed: onApply),
      AppConstants.gap8,
      BbButton(
        tapKey: otherProductKey,
        label: 'Anderes Produkt',
        isOutlined: true,
        onPressed: onOtherProduct,
      ),
    ],
  );
}

/// Core doesn't know the code: enter the meal by hand, add the product to
/// Open Food Facts, or scan again.
class ProductNotFoundView extends StatelessWidget {
  const ProductNotFoundView({
    super.key,
    required this.typeItKey,
    required this.offAddLinkKey,
    required this.rescanKey,
    required this.onTypeIt,
    required this.onAddToOff,
    required this.onRescan,
  });

  final Key typeItKey;
  final Key offAddLinkKey;
  final Key rescanKey;
  final VoidCallback onTypeIt;
  final VoidCallback onAddToOff;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dieses Produkt kennen wir noch nicht.', style: _titleStyle),
            AppConstants.gap8,
            Text(
              'Du kannst die Mahlzeit einfach selbst eintragen.',
              style: _bodyStyle,
            ),
          ],
        ),
      ),
      AppConstants.gap16,
      BbButton(
        tapKey: typeItKey,
        label: 'Selbst eintragen',
        onPressed: onTypeIt,
      ),
      AppConstants.gap8,
      RescanButton(tapKey: rescanKey, onTap: onRescan),
      AppConstants.gap8,
      Semantics(
        link: true,
        child: TextButton(
          key: offAddLinkKey,
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

/// A call failed: the message, „Nochmal versuchen" and „Nochmal scannen".
class ProductFailedView extends StatelessWidget {
  const ProductFailedView({
    super.key,
    required this.message,
    required this.retryKey,
    required this.rescanKey,
    required this.onRetry,
    required this.onRescan,
  });

  final String message;
  final Key retryKey;
  final Key rescanKey;
  final VoidCallback onRetry;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Panel(
        child: Semantics(
          liveRegion: true,
          child: Text(
            message,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.foreground,
              height: AppTheme.lineHeightBody,
            ),
          ),
        ),
      ),
      AppConstants.gap16,
      BbButton(
        tapKey: retryKey,
        label: 'Nochmal versuchen',
        onPressed: onRetry,
      ),
      AppConstants.gap8,
      RescanButton(tapKey: rescanKey, onTap: onRescan),
    ],
  );
}
