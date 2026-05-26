import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../services/storage_service.dart';
import '../services/sms_parser.dart';
import '../services/budget_service.dart';
import '../widgets/transaction_card.dart';
import '../widgets/filter_sheet.dart';
import 'transaction_form.dart';
import 'budget_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('com.upitracker/sms');
  final StorageService _storage = StorageService();
  final SmsParser _parser = SmsParser();
  final BudgetService _budgetService = BudgetService();
  List<Transaction> _transactions = [];

  String? _filterCategory;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _storage.init();
    await _budgetService.init();
    setState(() => _transactions = _storage.loadTransactions());
    _setupSmsListener();
  }

  void _setupSmsListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final body = call.arguments['body'] as String;
        final tx = _parser.parse(body);
        if (tx != null && tx.isDebit) {
          setState(() => _transactions.insert(0, tx));
          _storage.saveTransactions(_transactions);
          _showDopamineSnack(tx);
        }
      }
    });
  }

  void _showDopamineSnack(Transaction tx) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Logged ₹${tx.amount.toStringAsFixed(0)} at ${tx.merchant}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  List<Transaction> get _filteredTransactions {
    return _transactions.where((tx) {
      final t = tx;
      if (_filterCategory != null && t.category != _filterCategory) return false;
      if (_filterStartDate != null && t.date.isBefore(_filterStartDate!)) return false;
      if (_filterEndDate != null) {
        final end = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
        if (t.date.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _filterCategory = null;
      _filterStartDate = null;
      _filterEndDate = null;
    });
  }

  void _showForm({Transaction? transaction, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TransactionForm(
        transaction: transaction,
        index: index,
        onSave: (tx, idx) {
          setState(() {
            if (idx != null) {
              if (tx == transaction) {
                _transactions.removeAt(idx);
              } else {
                _transactions[idx] = tx;
              }
            } else {
              _transactions.insert(0, tx);
            }
          });
          _storage.saveTransactions(_transactions);
          if (idx == null || tx != transaction) {
            _showDopamineSnack(tx);
          }
        },
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterSheet(
        initialCategory: _filterCategory,
        initialStartDate: _filterStartDate,
        initialEndDate: _filterEndDate,
        onApply: (cat, start, end) {
          setState(() {
            _filterCategory = cat;
            _filterStartDate = start;
            _filterEndDate = end;
          });
        },
        onClear: _clearFilters,
      ),
    );
  }

  Widget _buildStickyHeader() {
    final now = DateTime.now();
    final monthTransactions = _transactions.where((tx) {
      return tx.date.month == now.month && tx.date.year == now.year && tx.isDebit;
    });

    final spent = monthTransactions.fold(0.0, (sum, t) => sum + t.amount);
    final budgets = _budgetService.loadBudgets(now.month, now.year);
    final totalLimit = _budgetService.getTotalLimit(budgets);
    final remaining = totalLimit - spent;

    if (totalLimit <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${now.month}/${now.year}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          Text(
            remaining >= 0
                ? '₹${remaining.toStringAsFixed(0)} left this month'
                : '₹${(-remaining).toStringAsFixed(0)} over budget',
            style: TextStyle(
              color: remaining >= 0 ? Colors.green.shade700 : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    final displayList = _filteredTransactions;
    final activeFilters = (_filterCategory != null ? 1 : 0) +
        (_filterStartDate != null ? 1 : 0) +
        (_filterEndDate != null ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilters,
              ),
              if (activeFilters > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$activeFilters',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStickyHeader(),
          Expanded(
            child: displayList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sms_failed, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No transactions yet', style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(
                          'Send a UPI SMS or tap + to add manually',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final tx = displayList[index];
                      return TransactionCard(
                        transaction: tx,
                        onTap: () => _showForm(
                          transaction: tx,
                          index: _transactions.indexOf(tx),
                        ),
                        onDuplicate: () {
                          final duplicate = Transaction(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            merchant: tx.merchant,
                            amount: tx.amount,
                            category: tx.category,
                            date: DateTime.now(),
                            isDebit: true,
                            rawSms: null,
                            isManual: true,
                          );
                          setState(() => _transactions.insert(0, duplicate));
                          _storage.saveTransactions(_transactions);
                          _showDopamineSnack(duplicate);
                        },
                        onDelete: () {
                          setState(() => _transactions.remove(tx));
                          _storage.saveTransactions(_transactions);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildTransactionList(),
      const BudgetScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
        ],
      ),
    );
  }
}