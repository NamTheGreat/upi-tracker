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
  State createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State {
  final BudgetService _budgetService = BudgetService();
  final StorageService _storageService = StorageService();
  
  List<Budget> _budgets = [];
  List<Transaction> _transactions = [];
  bool _loading = true;
  DateTime _currentMonth = DateTime.now();

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

  void _showBudgetForm({Budget? existing}) {
    final limitController = TextEditingController();
    String selectedCategory = existing?.category ?? CATEGORIES[0];
    double threshold = existing?.alertThreshold ?? 0.8;

    if (existing != null) {
      limitController.text = existing.limit.toString();
    }

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
                if (existing == null)
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
                    existing.category,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: limitController,
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
                          category: existing?.category ?? selectedCategory,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final monthName = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Month selector
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
          
          // Total budget progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Card(
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

          const Divider(),

          // Category budgets
          Expanded(
            child: _budgets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No budgets set', style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to set your first budget',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _budgets.length,
                    itemBuilder: (context, index) {
                      final budget = _budgets[index];
                      final spent = _budgetService.getSpent(
                        budget.category,
                        _currentMonth.month,
                        _currentMonth.year,
                        _transactions,
                      );
                      return BudgetProgress(
                        label: budget.category,
                        spent: spent,
                        limit: budget.limit,
                        alertThreshold: budget.alertThreshold,
                        onTap: () => _showBudgetForm(existing: budget),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBudgetForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}