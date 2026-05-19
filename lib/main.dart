import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

const List<String> CATEGORIES = [
  'Food',
  'Grocery',
  'Shopping',
  'Travel',
  'Utilities',
  'Entertainment',
  'Health',
  'Transfer',
  'Rent',
  'Education',
  'Other',
];

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UPI Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}

class Transaction {
  String id;
  String merchant;
  double amount;
  String category;
  DateTime date;
  bool isDebit;
  String? rawSms;
  bool isManual;

  Transaction({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.date,
    this.isDebit = true,
    this.rawSms,
    this.isManual = false,
  });

  Map toJson() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'isDebit': isDebit,
      'rawSms': rawSms,
      'isManual': isManual,
    };
  }

  static Transaction fromJson(Map json) {
    return Transaction(
      id: json['id'],
      merchant: json['merchant'],
      amount: json['amount'],
      category: json['category'],
      date: DateTime.parse(json['date']),
      isDebit: json['isDebit'],
      rawSms: json['rawSms'],
      isManual: json['isManual'] ?? false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State {
  static const platform = MethodChannel('com.upitracker/sms');
  List _transactions = [];
  SharedPreferences? _prefs;

  // Filters
  
  String? _filterCategory;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    _initStorage();
    _setupSmsListener();
  }

  void _setupSmsListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final body = call.arguments['body'] as String;
        final tx = _parseSms(body);
        if (tx != null && tx.isDebit) {
          setState(() {
            _transactions.insert(0, tx);
          });
          _saveTransactions();
        }
      }
    });
  }

  Future<void> _initStorage() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getString('transactions');
    if (saved != null && saved.isNotEmpty) {
      try {
        final list = jsonDecode(saved) as List;
        setState(() {
          _transactions = list
              .map((item) => Transaction.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        });
      } catch (e) {
        debugPrint('Load error: $e');
      }
    }
  }

  Future<void> _saveTransactions() async {
    final list = _transactions.map((tx) => (tx as Transaction).toJson()).toList();
    await _prefs?.setString('transactions', jsonEncode(list));
  }

  Transaction? _parseSms(String body) {
    final lower = body.toLowerCase();

    final isUPI = lower.contains('upi') ||
        lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('inr') ||
        lower.contains('rs.') ||
        lower.contains('trf') ||
        lower.contains('transfer');

    if (!isUPI) return null;

    final isDebit = !lower.contains('credited') && !lower.contains('received');

    final amountPatterns = [
      RegExp(r'(?:inr|rs\.?|₹)\s*([\d,]+\.?\d{0,2})\b', caseSensitive: false),
      RegExp(r'(?:debited|credited|received|paid|sent)\s+(?:by|for|of|with)?\s*([\d,]+\.?\d{0,2})\b', caseSensitive: false),
      RegExp(r'(?:for|of)\s+(?:inr|rs\.?|₹)?\s*([\d,]+\.?\d{0,2})\b', caseSensitive: false),
      RegExp(r'\b([\d,]+\.?\d{0,2})\b(?=\s*(?:on|via|upi|to|from|trf|transfer|date))', caseSensitive: false),
    ];

    double amount = 0;
    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final parsed = double.tryParse(
          match.group(1)?.replaceAll(',', '') ?? '0',
        ) ?? 0;
        if (parsed > 0) {
          amount = parsed;
          break;
        }
      }
    }

    if (amount > 100000 || amount == 0) {
      return Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        merchant: 'Invalid',
        amount: amount,
        category: 'Parse Error',
        date: DateTime.now(),
        isDebit: isDebit,
        rawSms: body,
      );
    }

    String merchant = 'Unknown';
    final merchantPatterns = [
      RegExp(r'(?:trf|transfer)\s+to\s+([A-Za-z][A-Za-z0-9\s&]+?)(?:\s+Ref|\s+If|\s+for|\s+via|$)', caseSensitive: false),
      RegExp(r'towards\s+([A-Za-z][A-Za-z0-9\s&]+?)(?:\s+for|\s+via|\s+UPI|\s+on|\s+\d)', caseSensitive: false),
      RegExp(r'(?:to|from)\s*:?\s*([A-Za-z][A-Za-z0-9\s&]+?)(?:\s+for|\s+via|\s+UPI|\s+Ref|\s+If)', caseSensitive: false),
    ];

    for (final pattern in merchantPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        merchant = match.group(1)?.trim() ?? 'Unknown';
        if (merchant.isNotEmpty && merchant != 'Unknown') break;
      }
    }

    String category = 'Unknown';
    final rules = {
      'Food': r'swiggy|zomato|dominos|foodpanda|uber.*eats|restaurant',
      'Grocery': r'bigbasket|blinkit|zepto|dmart|grocery|grofers',
      'Shopping': r'amazon|flipkart|myntra|ajio|nykaa',
      'Travel': r'uber|ola|rapido|redbus|makemytrip|irctc',
      'Utilities': r'jio|airtel|vodafone|bsnl|electricity|recharge',
      'Entertainment': r'netflix|prime|hotstar|spotify|youtube',
      'Health': r'pharmacy|medplus|apollo|1mg|netmeds',
      'Transfer': r'trf|transfer',
    };
    for (final entry in rules.entries) {
      if (RegExp(entry.value, caseSensitive: false).hasMatch(body)) {
        category = entry.key;
        break;
      }
    }

    return Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      merchant: merchant,
      amount: amount,
      category: category,
      date: DateTime.now(),
      isDebit: isDebit,
      rawSms: body,
    );
  }

  List get _filteredTransactions {
    return _transactions.where((tx) {
      final t = tx as Transaction;
      if (_filterCategory != null && t.category != _filterCategory) {
        return false;
      }
      if (_filterStartDate != null && t.date.isBefore(_filterStartDate!)) {
        return false;
      }
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

  void _showTransactionForm({Transaction? transaction, int? index}) {
    final isEdit = transaction != null;
    final merchantController = TextEditingController(text: isEdit ? transaction.merchant : '');
    final amountController = TextEditingController(text: isEdit ? transaction.amount.toString() : '');
    String selectedCategory = isEdit ? transaction!.category : CATEGORIES[0];
    DateTime selectedDate = isEdit ? transaction!.date : DateTime.now();

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
            builder: (context, setModalState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isEdit ? 'Edit Transaction' : 'Add Transaction',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: merchantController,
                    decoration: const InputDecoration(
                      labelText: 'Merchant *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.store),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: CATEGORIES.map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    )).toList(),
                    onChanged: (val) => setModalState(() => selectedCategory = val!),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Date'),
                    subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (isEdit) ...[
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _transactions.removeAt(index!);
                            });
                            _saveTransactions();
                            Navigator.pop(context);
                          },
                          child: const Text('DELETE', style: TextStyle(color: Colors.red)),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () {
                            final merchant = merchantController.text.trim();
                            final amountText = amountController.text.trim();

                            String? errorTitle;
                            String? errorMessage;

                            if (merchant.isEmpty && amountText.isEmpty) {
                              errorTitle = 'Missing Fields';
                              errorMessage = 'Please enter both merchant name and amount.';
                            } else if (merchant.isEmpty) {
                              errorTitle = 'Missing Merchant';
                              errorMessage = 'Please enter a merchant name.';
                            } else if (amountText.isEmpty) {
                              errorTitle = 'Missing Amount';
                              errorMessage = 'Please enter an amount.';
                            } else {
                              final amount = double.tryParse(amountText);
                              if (amount == null) {
                                errorTitle = 'Invalid Amount';
                                errorMessage = 'Please enter a valid number for the amount.';
                              } else if (amount <= 0) {
                                errorTitle = 'Invalid Amount';
                                errorMessage = 'Amount must be greater than 0.';
                              }
                            }

                            if (errorTitle != null) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text(errorTitle!),
                                  content: Text(errorMessage!),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            final amount = double.parse(amountText);

                            final duplicate = Transaction(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              merchant: merchant,
                              amount: amount,
                              category: selectedCategory,
                              date: DateTime.now(),
                              isDebit: true,
                              rawSms: null,
                              isManual: true,
                            );
                            setState(() => _transactions.insert(0, duplicate));
                            _saveTransactions();
                            Navigator.pop(context);
                          },
                          child: const Text('DUPLICATE'),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        const Spacer(),
                      ],
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final merchant = merchantController.text.trim();
                          final amountText = amountController.text.trim();

                          String? errorTitle;
                          String? errorMessage;

                          if (merchant.isEmpty && amountText.isEmpty) {
                            errorTitle = 'Missing Fields';
                            errorMessage = 'Please enter both merchant name and amount.';
                          } else if (merchant.isEmpty) {
                            errorTitle = 'Missing Merchant';
                            errorMessage = 'Please enter a merchant name.';
                          } else if (amountText.isEmpty) {
                            errorTitle = 'Missing Amount';
                            errorMessage = 'Please enter an amount.';
                          } else {
                            final amount = double.tryParse(amountText);
                            if (amount == null) {
                              errorTitle = 'Invalid Amount';
                              errorMessage = 'Please enter a valid number for the amount.';
                            } else if (amount <= 0) {
                              errorTitle = 'Invalid Amount';
                              errorMessage = 'Amount must be greater than 0.';
                            }
                          }

                          if (errorTitle != null) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(errorTitle!),
                                content: Text(errorMessage!),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          final amount = double.parse(amountText);

                          final newTx = Transaction(
                            id: isEdit ? transaction!.id : DateTime.now().millisecondsSinceEpoch.toString(),
                            merchant: merchant,
                            amount: amount,
                            category: selectedCategory,
                            date: selectedDate,
                            isDebit: true,
                            rawSms: isEdit ? transaction!.rawSms : null,
                            isManual: isEdit ? transaction!.isManual : true,
                          );

                          setState(() {
                            if (isEdit) {
                              _transactions[index!] = newTx;
                            } else {
                              _transactions.insert(0, newTx);
                            }
                          });
                          _saveTransactions();
                          Navigator.pop(context);
                        },
                        child: Text(isEdit ? 'SAVE' : 'ADD'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    String? tempCategory = _filterCategory;
    DateTime? tempStart = _filterStartDate;
    DateTime? tempEnd = _filterEndDate;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String?>(
                value: tempCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Categories')),
                  ...CATEGORIES.map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  )),
                ],
                onChanged: (val) => setModalState(() => tempCategory = val),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                leading: const Icon(Icons.date_range),
                title: const Text('Start Date'),
                subtitle: Text(tempStart != null ? '${tempStart!.day}/${tempStart!.month}/${tempStart!.year}' : 'Any'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: tempStart ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setModalState(() => tempStart = picked);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                leading: const Icon(Icons.date_range),
                title: const Text('End Date'),
                subtitle: Text(tempEnd != null ? '${tempEnd!.day}/${tempEnd!.month}/${tempEnd!.year}' : 'Any'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: tempEnd ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setModalState(() => tempEnd = picked);
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _clearFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('CLEAR ALL'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterCategory = tempCategory;
                        _filterStartDate = tempStart;
                        _filterEndDate = tempEnd;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('APPLY'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
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
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tx.isDebit ? Colors.red.shade100 : Colors.green.shade100,
                      child: Icon(
                        tx.isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                        color: tx.isDebit ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(tx.merchant, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${tx.category} • ${_formatDate(tx.date)}'),
                    trailing: Text(
                      '${tx.isDebit ? '-' : '+'}₹${tx.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tx.isDebit ? Colors.red : Colors.green,
                      ),
                    ),
                    onTap: () => _showTransactionForm(
                      transaction: tx,
                      index: _transactions.indexOf(tx),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTransactionForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}
