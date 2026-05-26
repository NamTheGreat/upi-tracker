import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/budget_service.dart';
import '../services/storage_service.dart';
import '../widgets/budget_progress.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final BudgetService _budgetService = BudgetService();
  final StorageService _storageService = StorageService();

  List<Budget> _budgets = [];
  List<<Transaction> _transactions = [];
  bool _loading = true;
  DateTime _currentMonth = DateTime.now();
  bool _showAllCategories = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _budgetService.init();
    await _storageService.init();

    setState(() {
      _transactions = _storageService.loadTransactions();
      _budgets = _budgetService.loadBudgets(_currentMonth.month, _currentMonth.year);
      _loading = false;
    });
  }

  double get _totalSpent => _budgetService.getTotalSpent(_currentMonth.month, _currentMonth.year, _transactions);
  double get _totalLimit => _budgetService.getTotalLimit(_budgets);

  List<String> get _activeCategories {
    final withBudget = _budgets.map((b) => b.category).toSet();
    final withTransactions = _transactions
        .where((t) => t.date.month == _currentMonth.month && t.date.year == _currentMonth.year)
        .map((t) => t.category)
        .toSet();
    return withBudget.union(withTransactions).toList()..sort();
  }

  List<String> get _suggestedCategories {
    if (_activeCategories.isNotEmpty) return _activeCategories;
    return ['Food', 'Grocery', 'Travel'];
  }

  List<String> get _hiddenCategories {
    return CATEGORIES.where((c) => !_activeCategories.contains(c)).toList();
  }

  void _showBudgetForm({String? category, Budget? existing}) {
    final limitController = TextEditingController(
      text: existing != null ? existing.limit.toString() : '',
    );
    double threshold = existing?.alertThreshold ?? 0.8;
    String selectedCategory = category ?? existing?.category ?? CATEGORIES[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing != null ? 'Edit Budget' : 'Set Budget',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (existing == null && category == null)
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: CATEGORIES.map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    )).toList(),
                    onChanged: (val) => setModalState(() => selectedCategory = val!),
                  )
                else
                  Text(
                    selectedCategory,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: limitController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Monthly Limit (₹)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                Text('Alert at: ${(threshold * 100).toStringAsFixed(0)}%', style: TextStyle(color: Colors.grey.shade600)),
                Slider(
                  value: threshold,
                  min: 0.5,
                  max: 0.95,
                  divisions: 9,
                  label: '${(threshold * 100).toStringAsFixed(0)}%',
                  onChanged: (val) => setModalState(() => threshold = val),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final limit = double.tryParse(limitController.text.trim()) ?? 0;
                        if (limit <= 0) return;

                        final budget = Budget(
                          category: selectedCategory,
                          limit: limit,
                          alertThreshold: threshold,
                          month: _currentMonth.month,
                          year: _currentMonth.year,
                        );

                        _saveBudget(budget);
                        Navigator.pop(context);
                      },
                      child: const Text('SAVE'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveBudget(Budget budget) async {
    final updated = _budgets.where((b) => b.category != budget.category).toList();
    updated.add(budget);
    await _budgetService.saveBudgets(updated);
    setState(() => _budgets = updated);
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
      _budgets = _budgetService.loadBudgets(_currentMonth.month, _currentMonth.year);
    });
  }

  String? _findSuggestion(String category, double spent, double limit) {
    if (spent <= limit) return null;

    final overAmount = spent - limit;
    for (final budget in _budgets) {
      if (budget.category == category) continue;
      final catSpent = _budgetService.getSpent(
        budget.category, _currentMonth.month, _currentMonth.year, _transactions,
      );
      final remaining = budget.limit - catSpent;
      if (remaining > overAmount) {
        return 'Move ₹${overAmount.toStringAsFixed(0)} from ${budget.category}?';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final monthName = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final displayCategories = _showAllCategories ? CATEGORIES : _suggestedCategories;
    final hasMore = _hiddenCategories.isNotEmpty && !_showAllCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '${monthName[_currentMonth.month]} ${_currentMonth.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          if (_budgets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Card(
                elevation: 0,
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BudgetProgress(
                    label: 'Total Budget',
                    spent: _totalSpent,
                    limit: _totalLimit,
                    alertThreshold: 0.8,
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: displayCategories.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (hasMore && index == displayCategories.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _showAllCategories = true),
                      icon: const Icon(Icons.expand_more),
                      label: Text('${_hiddenCategories.length} more categories'),
                    ),
                  );
                }

                final category = displayCategories[index];
                final existing = _budgets.firstWhere(
                  (b) => b.category == category,
                  orElse: () => Budget(
                    category: category,
                    limit: 0,
                    month: _currentMonth.month,
                    year: _currentMonth.year,
                  ),
                );

                final spent = _budgetService.getSpent(
                  category, _currentMonth.month, _currentMonth.year, _transactions,
                );

                if (existing.limit <= 0) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade100,
                      child: Icon(Icons.add, color: Colors.grey.shade400),
                    ),
                    title: Text(category),
                    subtitle: Text('₹${spent.toStringAsFixed(0)} spent this month'),
                    trailing: TextButton(
                      onPressed: () => _showBudgetForm(category: category),
                      child: const Text('SET BUDGET'),
                    ),
                  );
                }

                return BudgetProgress(
                  label: category,
                  spent: spent,
                  limit: existing.limit,
                  alertThreshold: existing.alertThreshold,
                  suggestion: _findSuggestion(category, spent, existing.limit),
                  onTap: () => _showBudgetForm(category: category, existing: existing),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _budgets.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showBudgetForm(),
              icon: const Icon(Icons.add),
              label: const Text('Set Budget'),
            )
          : null,
    );
  }
}