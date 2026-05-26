import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import 'package:flutter/material.dart';

class BudgetService {
  static const String _budgetsKey = 'budgets';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<Budget> loadBudgets(int month, int year) {
    final saved = _prefs?.getString(_budgetsKey);
    if (saved == null || saved.isEmpty) return [];
    try {
      final list = jsonDecode(saved) as List;
      return list
          .map((item) => Budget.fromJson(Map<String, dynamic>.from(item)))
          .where((b) => b.month == month && b.year == year)
          .toList();
    } catch (e) {
      debugPrint('Load budgets error: $e');
      return [];
    }
  }

  Future<void> saveBudgets(List<Budget> budgets) async {
    // Load all existing budgets
    final allBudgets = _loadAllBudgets();
    
    // Remove budgets for same month/year/category
    final month = budgets.first.month;
    final year = budgets.first.year;
    allBudgets.removeWhere((b) => b.month == month && b.year == year);
    
    // Add new budgets
    allBudgets.addAll(budgets);
    
    final list = allBudgets.map((b) => b.toJson()).toList();
    await _prefs?.setString(_budgetsKey, jsonEncode(list));
  }

  List<Budget> _loadAllBudgets() {
    final saved = _prefs?.getString(_budgetsKey);
    if (saved == null || saved.isEmpty) return [];
    try {
      final list = jsonDecode(saved) as List;
      return list.map((item) => Budget.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      return [];
    }
  }

  double getSpent(String category, int month, int year, List<Transaction> transactions) {
    return transactions
        .where((t) => 
            t.category == category && 
            t.date.month == month && 
            t.date.year == year &&
            t.isDebit)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getTotalSpent(int month, int year, List<Transaction> transactions) {
    return transactions
        .where((t) => t.date.month == month && t.date.year == year && t.isDebit)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getTotalLimit(List<Budget> budgets) {
    return budgets.fold(0.0, (sum, b) => sum + b.limit);
  }

  Color getProgressColor(double spent, double limit, double threshold) {
    if (limit <= 0) return Colors.grey;
    final ratio = spent / limit;
    if (ratio >= 1.0) return Colors.red;
    if (ratio >= threshold) return Colors.orange;
    if (ratio >= 0.5) return Colors.blue;
    return Colors.green;
  }
}