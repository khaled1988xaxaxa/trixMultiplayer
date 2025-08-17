// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Trix';

  @override
  String get welcome => 'Welcome to Trix';

  @override
  String get newGame => 'New Game';

  @override
  String get joinGame => 'Join Game';

  @override
  String get settings => 'Settings';

  @override
  String get players => 'Players';

  @override
  String get score => 'Score';

  @override
  String get trump => 'Trump';

  @override
  String get noTrump => 'No Trump';

  @override
  String get bid => 'Bid';

  @override
  String get pass => 'Pass';

  @override
  String get hearts => 'Hearts';

  @override
  String get diamonds => 'Diamonds';

  @override
  String get clubs => 'Clubs';

  @override
  String get spades => 'Spades';
}
