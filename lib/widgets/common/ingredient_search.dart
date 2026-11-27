import 'dart:async';

import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/ingredient_search_result.dart';
import 'bb_icon_tap.dart';
import 'bb_labeled_field.dart';
import 'tap_target.dart';

/// The „Zutaten" card: the added ingredients as chips, and „+ Hinzufügen",
/// a search field with the catalog's best matches ([suggestions], ranked by
/// the search) below it, above the keyboard. A name that isn't in the
/// catalog is added only explicitly, with its „Name hinzufügen" row:
/// Return adds an exact catalog match, never the raw text (it points to the
/// row instead).
class IngredientSearch extends StatefulWidget {
  final List<String> ingredients;
  final List<IngredientSearchResult> suggestions;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onDeleteIngredient;

  const IngredientSearch({
    super.key,
    required this.ingredients,
    required this.suggestions,
    required this.onSearch,
    required this.onAdd,
    required this.onRemove,
    required this.onDeleteIngredient,
  });

  /// The row adding the typed name („Name hinzufügen").
  static const addTypedKey = Key('ingredient_search_add_typed');

  @override
  State<IngredientSearch> createState() => _IngredientSearchState();
}

class _IngredientSearchState extends State<IngredientSearch> {
  static const _searchDebounce = Duration(milliseconds: 300);

  /// How many catalog matches show at once (they must fit above the
  /// keyboard).
  static const _maxSuggestions = 5;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _suggestionsKey = GlobalKey();
  bool _isAdding = false;
  Timer? _searchDebounceTimer;

  /// Return was pressed before the search answered: an exact match among
  /// its results is added then.
  bool _addExactOnResults = false;

  /// Return found no exact match: a hint points to the „hinzufügen" row
  /// until the text changes.
  bool _showSubmitHint = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      // Leaving an empty field closes it; typed text stays for its rows.
      if (!_focusNode.hasFocus && _isAdding && _typed.isEmpty) _close();
    });
  }

  @override
  void didUpdateWidget(IngredientSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.suggestions, widget.suggestions)) {
      final exact = _addExactOnResults ? _exactMatch : null;
      _addExactOnResults = false;
      if (exact != null) {
        // Not during this build: adding updates the host.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isAdding) _add(exact.name);
        });
        return;
      }
      _revealSuggestions();
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () => widget.onSearch(value));
  }

  void _flushSearch(String value) {
    _searchDebounceTimer?.cancel();
    widget.onSearch(value);
  }

  String get _typed => _controller.text.trim();

  /// The suggestion named exactly like the typed text (ignoring case).
  IngredientSearchResult? get _exactMatch {
    final typed = _typed.toLowerCase();
    if (typed.isEmpty) return null;
    for (final s in widget.suggestions) {
      if (s.name.toLowerCase() == typed) return s;
    }
    return null;
  }

  void _add(String name) {
    widget.onAdd(name);
    _close();
  }

  void _close() {
    _controller.clear();
    _flushSearch('');
    setState(() {
      _isAdding = false;
      _showSubmitHint = false;
    });
  }

  /// Return: adds the exact catalog match; anything else stays in the field
  /// (keyboard open) to pick a suggestion or its „hinzufügen" row.
  void _onSubmitted(String value) {
    final exact = _exactMatch;
    if (exact != null) {
      _add(exact.name);
    } else if (_typed.isEmpty) {
      _close();
    } else {
      // The results may not be in yet: an exact match still gets added.
      _addExactOnResults = true;
      setState(() => _showSubmitHint = true);
      _flushSearch(value);
    }
  }

  /// Scrolls the suggestions up above the keyboard once they changed.
  void _revealSuggestions() {
    if (!_isAdding) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _suggestionsKey.currentContext;
      if (!mounted || !_isAdding || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: AppConstants.animFast,
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _scrollToField() {
    // Bail if no longer in adding mode — the TextField has unmounted and
    // _focusNode.context now points at a deactivated element. This can
    // happen when the user submits the field and Flutter fires the
    // delayed scroll callback after _isAdding flips back to false.
    if (!mounted || !_isAdding) return;
    final ctx = _focusNode.context;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: AppConstants.animMedium,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSuggestions = widget.suggestions
        .where((s) => !widget.ingredients.contains(s.name))
        .take(_maxSuggestions)
        .toList();
    final typed = _typed;
    final showAddTyped =
        _isAdding &&
        typed.isNotEmpty &&
        _exactMatch == null &&
        !widget.ingredients.any((i) => i.toLowerCase() == typed.toLowerCase());

    return Container(
      padding: AppConstants.paddingMd,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Zutaten',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeSubtitle,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppConstants.spacing12),
              if (_isAdding)
                Expanded(
                  child: BbLabeledField(
                    label: 'Zutat suchen',
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: const TextStyle(fontSize: AppTheme.fontSizeBody),
                      decoration: InputDecoration(
                        hintText: 'Zutat suchen…',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacing12,
                          vertical: AppConstants.spacingSm,
                        ),
                        suffixIcon: BbIconTap(
                          icon: Icons.close,
                          iconSize: AppConstants.iconSizeSm,
                          semanticLabel: 'Suche schließen',
                          onTap: _close,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: AppConstants.minTapTarget,
                          minHeight: AppConstants.minTapTarget,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onChanged: (value) {
                        _addExactOnResults = false;
                        // for the „hinzufügen" row and the Return hint
                        setState(() => _showSubmitHint = false);
                        _onQueryChanged(value);
                        _revealSuggestions();
                      },
                      // Return must not close the keyboard by itself:
                      // [_onSubmitted] decides.
                      onEditingComplete: () {},
                      onSubmitted: _onSubmitted,
                    ),
                  ),
                )
              else
                // Wraps rather than overflows at a large text size.
                Flexible(
                  // One button; its name says what it adds.
                  child: Semantics(
                    container: true,
                    button: true,
                    label: 'Zutat hinzufügen',
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isAdding = true);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _focusNode.requestFocus();
                          // Delay to let the keyboard fully animate in before
                          // scrolling, otherwise the scroll target is wrong.
                          Future.delayed(AppConstants.animSlow, _scrollToField);
                        });
                      },
                      // 48 high to tap; the text stays where it was.
                      child: const TapTarget(
                        alignment: AlignmentDirectional.centerStart,
                        child: ExcludeSemantics(
                          child: Text(
                            '+ Hinzufügen',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeBody,
                              color: AppTheme.primaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (showAddTyped && _showSubmitHint)
            Padding(
              padding: const EdgeInsets.only(top: AppConstants.spacingXs),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'Tippe auf „‚$typed‘ hinzufügen“.',
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeCaptionLG,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ),
            ),
          if (_isAdding &&
              (filteredSuggestions.isNotEmpty || showAddTyped)) ...[
            Container(
              key: _suggestionsKey,
              margin: const EdgeInsets.only(top: AppConstants.spacingXs),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              // Transparent Material so the suggestion ListTiles have a
              // Material ancestor (Flutter ≥3.42 asserts otherwise); the card
              // background still shows through.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (final s in filteredSuggestions)
                      ListTile(
                        title: Text(s.name),
                        dense: true,
                        onTap: () => _add(s.name),
                        trailing: s.isOwn
                            ? IconButton(
                                tooltip: 'Zutat löschen',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: AppConstants.iconSizeClose,
                                  color: AppTheme.mutedForeground,
                                ),
                                onPressed: () =>
                                    widget.onDeleteIngredient(s.id),
                              )
                            : null,
                      ),
                    if (showAddTyped)
                      ListTile(
                        key: IngredientSearch.addTypedKey,
                        leading: const Icon(
                          Icons.add,
                          size: AppConstants.iconSizeSm,
                          color: AppTheme.primary,
                        ),
                        title: Text('„$typed“ hinzufügen'),
                        dense: true,
                        onTap: () => _add(typed),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (widget.ingredients.isNotEmpty) ...[
            AppConstants.gap8,
            Wrap(
              spacing: AppConstants.spacingSm,
              runSpacing: AppConstants.spacingSm,
              children: widget.ingredients.map((ingredient) {
                return Chip(
                  label: Text(ingredient),
                  labelStyle: const TextStyle(color: Colors.black),
                  onDeleted: () => widget.onRemove(ingredient),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
