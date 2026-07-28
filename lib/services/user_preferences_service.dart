import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user preferences and first-time user detection
class UserPreferencesService {
  static const String _firstTimeKey = 'first_time_user';
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _skipStepConfirmationKey = 'skip_step_confirmation';
  static const String _countryKey = 'user_country';
  static const String _currencyKey = 'user_currency';
  static const String _currencyCodeKey = 'user_currency_code';
  static const String _currencySymbolKey = 'user_currency_symbol';
  static Future<SharedPreferences>? _prefsFuture;

  // In-memory cache for synchronous reads (populated by warmUp or first read)
  static String? _cachedCountry;
  static String? _cachedCurrency;
  static String? _cachedCurrencyCode;
  static String? _cachedCurrencySymbol;

  static Future<SharedPreferences> _prefs() {
    _prefsFuture ??= SharedPreferences.getInstance();
    return _prefsFuture!;
  }

  /// Warm up shared preferences early to reduce first-read latency.
  static Future<void> warmUp() async {
    await _prefs();
  }

  /// Check if this is the first time the user is opening the app
  static Future<bool> isFirstTimeUser() async {
    final prefs = await _prefs();
    return prefs.getBool(_firstTimeKey) ?? true;
  }

  /// Mark that the user has completed onboarding
  static Future<void> markOnboardingComplete() async {
    final prefs = await _prefs();
    await prefs.setBool(_firstTimeKey, false);
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  /// Check if the user has completed onboarding
  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await _prefs();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Reset first-time user status (useful for testing)
  static Future<void> resetFirstTimeUser() async {
    final prefs = await _prefs();
    await prefs.remove(_firstTimeKey);
    await prefs.remove(_onboardingCompleteKey);
  }

  /// Whether step-by-step confirmation prompts should be skipped.
  static Future<bool> shouldSkipStepConfirmation() async {
    final prefs = await _prefs();
    return prefs.getBool(_skipStepConfirmationKey) ?? false;
  }

  /// Persist step confirmation preference.
  static Future<void> setSkipStepConfirmation(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(_skipStepConfirmationKey, value);
  }

  /// Reset confirmation preference to default behavior (show prompts).
  static Future<void> resetStepConfirmationPreference() async {
    final prefs = await _prefs();
    await prefs.remove(_skipStepConfirmationKey);
  }

  // ─── Country & Currency (propagated across the entire app) ─────────────

  /// Save the user's country selection (from onboarding or settings).
  static Future<void> setCountry(String country) async {
    _cachedCountry = country;
    final prefs = await _prefs();
    await prefs.setString(_countryKey, country);
  }

  /// Get the user's country selection. Returns null if not set.
  static Future<String?> getCountry() async {
    if (_cachedCountry != null) return _cachedCountry;
    final prefs = await _prefs();
    _cachedCountry = prefs.getString(_countryKey);
    return _cachedCountry;
  }

  /// Synchronous country read (from cache). Returns null if not cached.
  static String? get countrySync => _cachedCountry;

  /// Save the user's currency selection (full string like 'USD (\$) — US Dollar').
  /// Also extracts and stores the currency code and symbol for fast access.
  static Future<void> setCurrency(String currency) async {
    _cachedCurrency = currency;
    final spaceIdx = currency.indexOf(' ');
    final code = spaceIdx > 0 ? currency.substring(0, spaceIdx) : 'USD';
    final parenStart = currency.indexOf('(');
    final parenEnd = currency.indexOf(')');
    final symbol = (parenStart >= 0 && parenEnd > parenStart)
        ? currency.substring(parenStart + 1, parenEnd)
        : '\$';
    _cachedCurrencyCode = code;
    _cachedCurrencySymbol = symbol;
    final prefs = await _prefs();
    await prefs.setString(_currencyKey, currency);
    await prefs.setString(_currencyCodeKey, code);
    await prefs.setString(_currencySymbolKey, symbol);
  }

  /// Get the user's currency selection (full string).
  static Future<String?> getCurrency() async {
    if (_cachedCurrency != null) return _cachedCurrency;
    final prefs = await _prefs();
    _cachedCurrency = prefs.getString(_currencyKey);
    _cachedCurrencyCode = prefs.getString(_currencyCodeKey);
    _cachedCurrencySymbol = prefs.getString(_currencySymbolKey);
    return _cachedCurrency;
  }

  /// Synchronous currency read (from cache).
  static String? get currencySync => _cachedCurrency;

  /// Synchronous currency code read (e.g. 'USD', 'EUR', 'GBP').
  /// Returns 'USD' if not set.
  static String get currencyCodeSync => _cachedCurrencyCode ?? 'USD';

  /// Synchronous currency symbol read (e.g. '\$', '€', '£').
  /// Returns '\$' if not set.
  static String get currencySymbolSync => _cachedCurrencySymbol ?? '\$';

  /// Load cached country/currency from SharedPreferences into memory.
  /// Called during app startup (warmUp) so synchronous reads work.
  static Future<void> loadCountryCurrency() async {
    final prefs = await _prefs();
    _cachedCountry = prefs.getString(_countryKey);
    _cachedCurrency = prefs.getString(_currencyKey);
    _cachedCurrencyCode = prefs.getString(_currencyCodeKey);
    _cachedCurrencySymbol = prefs.getString(_currencySymbolKey);
  }
}
