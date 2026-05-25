import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../services/storage_service.dart';
import '../services/sms_parser.dart';
import '../widgets/transaction_card.dart';
import '../widgets/filter_sheet.dart';
import 'transaction_form.dart';
import 'budget_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State createState() => _HomeScreenState();
}

class _HomeScreenState extends State {
  static const platform = MethodChannel('com.upitracker/sms');
  final StorageService _storage = StorageService();
  final SmsParser _parser = SmsParser();
  List _transactions = [];

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
          _storage.saveTransactions(_transactions.cast<Transaction>());
        }
      }
    });
  }

  List get _filteredTransactions {
    return _transactions.where((tx) {
      final t = tx as Transaction;
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
          _storage.saveTransactions(_transactions.cast<Transaction>());
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

  Widget _buildTransactionList() {
    final displayList = _filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: displayList.isEmpty
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
                final tx = displayList[index] as Transaction;
                return TransactionCard(
                  transaction: tx,
                  onTap: () => _showForm(
                    transaction: tx,
                    index: _transactions.indexOf(tx),
                  ),
                );
              },
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