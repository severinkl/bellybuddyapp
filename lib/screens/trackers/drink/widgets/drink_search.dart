import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../models/drink.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../services/haptic_service.dart';
import '../../../../services/supabase_service.dart';

class DrinkSearch extends ConsumerStatefulWidget {
  const DrinkSearch({super.key});

  @override
  ConsumerState<DrinkSearch> createState() => _DrinkSearchState();
}

class _DrinkSearchState extends ConsumerState<DrinkSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _overlayController = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _syncOverlay();
    } else {
      Future.delayed(AppConstants.animNormal, () {
        if (mounted && !_focusNode.hasFocus && _overlayController.isShowing) {
          _overlayController.hide();
        }
      });
    }
  }

  bool get _shouldShowCreateOption {
    final query = _controller.text.trim();
    if (query.isEmpty) return false;
    final suggestions = ref.read(drinkTrackerProvider).suggestions;
    return !suggestions.any(
      (d) => d.name.toLowerCase() == query.toLowerCase(),
    );
  }

  void _syncOverlay() {
    final suggestions = ref.read(drinkTrackerProvider).suggestions;
    final showCreate = _shouldShowCreateOption;
    if ((suggestions.isNotEmpty || showCreate) && _focusNode.hasFocus) {
      if (!_overlayController.isShowing) _overlayController.show();
    } else {
      if (_overlayController.isShowing) _overlayController.hide();
    }
  }

  void _selectDrink(Drink drink) {
    HapticService.selection();
    _controller.clear();
    _focusNode.unfocus();
    ref.read(drinkTrackerProvider.notifier).toggleDrink(drink);
  }

  Future<void> _createDrink() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    HapticService.selection();
    final messenger = ScaffoldMessenger.of(context);
    _controller.clear();
    _focusNode.unfocus();
    try {
      await ref.read(drinkTrackerProvider.notifier).createDrink(query);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('„$query" hinzugefügt')),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Getränk konnte nicht erstellt werden'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch suggestions to trigger rebuilds (updates overlay content)
    ref.watch(drinkTrackerProvider.select((s) => s.suggestions));

    // Sync overlay visibility after each build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncOverlay();
    });

    final screenWidth = MediaQuery.sizeOf(context).width;

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (_) {
        final suggestions = ref.read(drinkTrackerProvider).suggestions;
        final currentUserId = SupabaseService.userId;
        return CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                side: const BorderSide(color: AppTheme.border),
              ),
              color: AppTheme.card,
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: screenWidth - 48),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...suggestions.map((drink) {
                        final isOwn =
                            currentUserId != null &&
                            drink.addedByUserId == currentUserId;
                        return InkWell(
                          onTap: () => _selectDrink(drink),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    drink.name,
                                    style: const TextStyle(
                                      fontSize: AppTheme.fontSizeBody,
                                    ),
                                  ),
                                ),
                                if (isOwn)
                                  GestureDetector(
                                    onTap: () async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      try {
                                        await ref
                                            .read(
                                              drinkTrackerProvider.notifier,
                                            )
                                            .deleteDrink(drink);
                                      } catch (_) {
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Getränk konnte nicht gelöscht werden',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: AppTheme.destructive.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (_shouldShowCreateOption)
                        InkWell(
                          onTap: () => _createDrink(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add,
                                  size: 18,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '„${_controller.text.trim()}" hinzufügen',
                                    style: const TextStyle(
                                      fontSize: AppTheme.fontSizeBody,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Getränk suchen...',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: AppTheme.muted.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: ref.read(drinkTrackerProvider.notifier).searchDrinks,
          onTapOutside: (_) => _focusNode.unfocus(),
        ),
      ),
    );
  }
}
