import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const String _historyKey = 'merchant_category_history';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Map<String, String> loadHistory() {
    final saved = _prefs?.getString(_historyKey);
    if (saved == null || saved.isEmpty) return {};
    try {
      final map = jsonDecode(saved) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as String));
    } catch (e) {
      return {};
    }
  }

  Future<void> saveHistory(Map<String, String> history) async {
    await _prefs?.setString(_historyKey, jsonEncode(history));
  }

  String? predictCategory(String merchant) {
    final history = loadHistory();
    final normalized = merchant.toLowerCase().trim();
    return history[normalized];
  }

  Future<void> learn(String merchant, String category) async {
    final history = loadHistory();
    final normalized = merchant.toLowerCase().trim();
    history[normalized] = category;
    await saveHistory(history);
  }
}