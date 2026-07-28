import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the default currency for the entire application.
///
/// The selected currency is persisted in SharedPreferences and can be
/// read by any screen via [CurrencyService.instance.defaultCurrency] or
/// [CurrencyService.instance.formatAmount].
class CurrencyService extends ChangeNotifier {
  static const String _prefKey = 'pref_default_currency';

  static final CurrencyService _instance = CurrencyService._internal();
  static CurrencyService get instance => _instance;
  CurrencyService._internal();

  String _defaultCurrencyCode = 'USD';

  /// The current default currency code (e.g. 'USD', 'ZMW', 'EUR').
  String get defaultCurrencyCode => _defaultCurrencyCode;

  /// The symbol for the current default currency (e.g. '$', 'ZK', '€').
  String get defaultCurrencySymbol => getSymbol(_defaultCurrencyCode);

  /// Load the persisted currency choice (or default to 'USD').
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey) ?? 'USD';
      _defaultCurrencyCode = raw;
    } catch (_) {
      _defaultCurrencyCode = 'USD';
    }
    notifyListeners();
  }

  /// Set the default currency and persist the choice.
  Future<void> setDefaultCurrency(String code) async {
    if (_defaultCurrencyCode == code) return;
    _defaultCurrencyCode = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {
      // Silently ignore persistence failures.
    }
  }

  /// Format a monetary amount with the default currency symbol.
  String formatAmount(double amount, {int decimals = 2}) {
    return '$defaultCurrencySymbol${amount.toStringAsFixed(decimals)}';
  }

  /// Get the symbol for a given currency code.
  static String getSymbol(String code) {
    return _currencySymbols[code] ?? code;
  }

  /// All supported currencies with their codes, symbols, and names.
  static const List<CurrencyOption> supportedCurrencies = [
    CurrencyOption(code: 'USD', symbol: '\$', name: 'US Dollar'),
    CurrencyOption(code: 'ZMW', symbol: 'ZK', name: 'Zambian Kwacha'),
    CurrencyOption(code: 'EUR', symbol: '€', name: 'Euro'),
    CurrencyOption(code: 'GBP', symbol: '£', name: 'British Pound'),
    CurrencyOption(code: 'ZAR', symbol: 'R', name: 'South African Rand'),
    CurrencyOption(code: 'KES', symbol: 'KSh', name: 'Kenyan Shilling'),
    CurrencyOption(code: 'NGN', symbol: '₦', name: 'Nigerian Naira'),
    CurrencyOption(code: 'GHS', symbol: '₵', name: 'Ghanaian Cedi'),
    CurrencyOption(code: 'EGP', symbol: 'E£', name: 'Egyptian Pound'),
    CurrencyOption(code: 'RWF', symbol: 'RF', name: 'Rwandan Franc'),
    CurrencyOption(code: 'TZS', symbol: 'TSh', name: 'Tanzanian Shilling'),
    CurrencyOption(code: 'UGX', symbol: 'USh', name: 'Ugandan Shilling'),
    CurrencyOption(code: 'CNY', symbol: '¥', name: 'Chinese Yuan'),
    CurrencyOption(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
    CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    CurrencyOption(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
    CurrencyOption(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
    CurrencyOption(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc'),
    CurrencyOption(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real'),
    CurrencyOption(code: 'AED', symbol: 'AED', name: 'UAE Dirham'),
  ];

  static const Map<String, String> _currencySymbols = {
    'USD': '\$',
    'ZMW': 'ZK',
    'EUR': '€',
    'GBP': '£',
    'ZAR': 'R',
    'KES': 'KSh',
    'NGN': '₦',
    'GHS': '₵',
    'EGP': 'E£',
    'RWF': 'RF',
    'TZS': 'TSh',
    'UGX': 'USh',
    'CNY': '¥',
    'JPY': '¥',
    'INR': '₹',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'CHF': 'CHF',
    'BRL': 'R\$',
    'AED': 'AED',
  };
}

/// A supported currency option for the settings dropdown.
class CurrencyOption {
  final String code;
  final String symbol;
  final String name;

  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.name,
  });

  @override
  String toString() => '$code ($symbol) — $name';
}
