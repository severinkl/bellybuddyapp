import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../config/app_theme.dart';
import '../config/constants.dart';

/// The Buddy's name rules, the same wherever it is typed (the registration,
/// the onboarding, „Buddy umbenennen").
///
/// Its length is counted in characters as a person sees them (grapheme
/// clusters: „❤️" or an emoji family is one), up to
/// [AppConstants.buddyNameMaxLength]; the fields don't take more. A name
/// must also fit the database's check, which still counts code points
/// ([AppConstants.buddyNameMaxCodePoints]); a name of many emojis can pass
/// the first limit and not the second, and is then refused with
/// [tooManySymbols].
abstract final class BuddyNameRules {
  /// The error for an empty name.
  static const empty =
      'Bitte gib einen Namen mit 1 bis ${AppConstants.buddyNameMaxLength} '
      'Zeichen ein.';

  /// The error for a name the database can't store yet.
  static const tooManySymbols =
      'So viele Emojis passen leider nicht. Bitte kürze den Namen.';

  /// [text]'s length in characters as a person sees them.
  static int length(String text) => text.characters.length;

  /// Why [name] (as typed) can't be saved, or null when it can.
  static String? error(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return empty;
    if (!AppConstants.isValidBuddyName(trimmed)) {
      return length(trimmed) > AppConstants.buddyNameMaxLength
          ? empty
          : tooManySymbols;
    }
    return null;
  }

  /// The „n/20" counter of a name field showing [text].
  static Widget counter(String text, {required bool isFocused}) => Semantics(
    container: true,
    liveRegion: isFocused,
    child: Text(
      '${length(text)}/${AppConstants.buddyNameMaxLength}',
      style: const TextStyle(
        fontSize: AppTheme.fontSizeCaption,
        color: AppTheme.mutedForeground,
      ),
    ),
  );
}

/// Caps a name field at [AppConstants.buddyNameMaxLength] characters as a
/// person sees them, cutting only between whole characters. Typing at the
/// limit keeps the text as it was.
class BuddyNameLengthFormatter extends TextInputFormatter {
  const BuddyNameLengthFormatter();

  static const _max = AppConstants.buddyNameMaxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (BuddyNameRules.length(newValue.text) <= _max) return newValue;
    if (BuddyNameRules.length(oldValue.text) == _max &&
        oldValue.selection.isCollapsed) {
      return oldValue;
    }
    final text = newValue.text.characters.take(_max).toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
