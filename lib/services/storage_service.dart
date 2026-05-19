import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

class StorageService {
  static const String _transactionsKey = 'transactions';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<Transaction> loadTransactions() {
    final saved = _prefs?.getString(_transactionsKey);
    if (saved == null || saved.isEmpty) return [];
    try {
      final list = jsonDecode(saved) as List;
      return list.map((item) => Transaction.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      print('Load error: $e');
      return [];
    }
  }

  Future<void> saveTransactions(List<Transaction> transactions) async {
    final list = transactions.map((tx) => tx.toJson()).toList();
    await _prefs?.setString(_transactionsKey, jsonEncode(list));
  }

  Future<void> clearTransactions() async {
    await _prefs?.remove(_transactionsKey);
  }
}