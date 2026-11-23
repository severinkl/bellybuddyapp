import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';

/// The app's localization delegates (German only). Material's German
/// strings, but the scrim behind a sheet reads „Schließen" ([scrimLabel]).
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  _AppMaterialLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Material's German strings, with a scrim label screen readers can act on:
/// the stock one is „Gitter" (a literal „scrim").
class _AppMaterialLocalizationsDe extends MaterialLocalizationDe {
  const _AppMaterialLocalizationsDe({
    required super.localeName,
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  String get scrimLabel => modalBarrierDismissLabel;
}

class _AppMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _AppMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'de';

  /// Synchronous like the stock delegate (a [SynchronousFuture]), so the
  /// first frame already has the strings.
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      // Loads Material's date data for the locale first, as the stock
      // delegate does.
      GlobalMaterialLocalizations.delegate.load(locale).then((_) {
        final name = intl.Intl.canonicalizedLocale(locale.toString());
        final date = intl.DateFormat.localeExists(name) ? name : 'de';
        final number = intl.NumberFormat.localeExists(name) ? name : 'de';
        return _AppMaterialLocalizationsDe(
          localeName: name,
          fullYearFormat: intl.DateFormat.y(date),
          compactDateFormat: intl.DateFormat.yMd(date),
          shortDateFormat: intl.DateFormat.yMMMd(date),
          mediumDateFormat: intl.DateFormat.MMMEd(date),
          longDateFormat: intl.DateFormat.yMMMMEEEEd(date),
          yearMonthFormat: intl.DateFormat.yMMMM(date),
          shortMonthDayFormat: intl.DateFormat.MMMd(date),
          decimalFormat: intl.NumberFormat.decimalPattern(number),
          twoDigitZeroPaddedFormat: intl.NumberFormat('00', number),
        );
      });

  @override
  bool shouldReload(_AppMaterialLocalizationsDelegate old) => false;
}
