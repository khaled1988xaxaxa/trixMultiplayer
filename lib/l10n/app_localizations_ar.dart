// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تريكس';

  @override
  String get welcome => 'مرحباً بك في تريكس';

  @override
  String get newGame => 'لعبة جديدة';

  @override
  String get joinGame => 'انضم للعبة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get players => 'اللاعبون';

  @override
  String get score => 'النقاط';

  @override
  String get trump => 'صن';

  @override
  String get noTrump => 'بدون صن';

  @override
  String get bid => 'مزايدة';

  @override
  String get pass => 'بطاقة';

  @override
  String get hearts => 'كلب';

  @override
  String get diamonds => 'ديناري';

  @override
  String get clubs => 'سباتي';

  @override
  String get spades => 'بستوني';
}
