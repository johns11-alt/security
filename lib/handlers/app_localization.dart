class AppLocalization {
  AppLocalization(this.locale);

  final Locale locale;
  static AppLocalization? of(BuildContext context) {
    return Localizations.of<AppLocalization>(context, AppLocalization);
  }

  Map<String, String> _localizedValues = {};
  Map<String, String> _localizedCommonValues = {};

  Future load() async {
    //fortwnei ta json files poy balame emeis
    String jsonStringValues = await rootBundle.loadString(
        'lib/helpers/localization/languages/${locale.languageCode}.json');

    Map<String, dynamic> mappedJson = json.decode(jsonStringValues);

    _localizedValues =
        mappedJson.map((key, value) => MapEntry(key, value.toString()));

    String jsonStringCommonValues = await rootBundle.loadString(
        'packages/ime_common/lib/helpers/localization/languages/${locale.languageCode}.json');

    Map<String, dynamic> mappedCommonJson = json.decode(jsonStringCommonValues);

    _localizedCommonValues =
        mappedCommonJson.map((key, value) => MapEntry(key, value.toString()));
  }

  String? getTranslatedValue(String key) {
    return _localizedValues[key] ?? '';
  }

  String? getTranslatedCommonValue(String key) {
    return _localizedCommonValues[key] ?? '';
  }

  static const LocalizationsDelegate<AppLocalization> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalization> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return [
      'en',
      'el',
    ].contains(locale.languageCode);
  }

  @override
  Future<AppLocalization> load(Locale locale) async {
    AppLocalization localization = AppLocalization(locale);
    await localization.load();
    return localization;
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalization> old) => false;
}

