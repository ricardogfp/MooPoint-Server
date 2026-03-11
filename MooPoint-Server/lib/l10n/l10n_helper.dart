import 'package:flutter/widgets.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';

class L10n {
  /// Returns a safe instance of [AppLocalizations].
  /// If [AppLocalizations.of(context)] returns null, it returns a default English instance
  /// to prevent 'Null check operator used on a null value' crashes.
  static AppLocalizations of(BuildContext context) {
    return AppLocalizations.of(context) ?? AppLocalizationsEn();
  }
}

extension ContextL10n on BuildContext {
  AppLocalizations get l10n => L10n.of(this);
}
