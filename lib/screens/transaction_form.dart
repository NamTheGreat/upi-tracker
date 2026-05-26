import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/transaction.dart';
import '../services/history_service.dart';

class TransactionForm extends StatefulWidget {
  final Transaction? transaction;
  final int? index;
  final Function(Transaction, int?) onSave;

  const TransactionForm({
    super.key,
    this.transaction,
    this.index,
    required this.onSave,
  });

  @override
  State createState() => _TransactionFormState();
}

class _TransactionFormState extends State<<TransactionForm> {
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late String _selectedCategory;
  late DateTime _selectedDate;
  final HistoryService _history = HistoryService();
  String? _categoryHint;

  @override
  void initState() {
    super.initState();
    final isEdit = widget.transaction != null;
    _merchantController = TextEditingController(text: isEdit ? widget.transaction!.merchant : '');
    _amountController = TextEditingController(text: isEdit ? widget.transaction!.amount.toString() : '');
    _selectedCategory = isEdit ? widget.transaction!.category : CATEGORIES[0];
    _selectedDate = isEdit ? widget.transaction!.date : DateTime.now();
    _history.init();
    _checkHistory();
  }

  void _checkHistory() {
    final merchant = _merchantController.text.trim();
    if (merchant.isNotEmpty) {
      final predicted = _history.predictCategory(merchant);
      if (predicted != null && predicted != _selectedCategory) {
        setState(() {
          _categoryHint = 'Usually $predicted';
          _selectedCategory = predicted;
        });
      }
    }
  }

  void _validateAndSave() {
    final merchant = _merchantController.text.trim();
    final amountText = _amountController.text.trim();

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
          title: Text(errorTitle),
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
    final isEdit = widget.transaction != null;

    final newTx = Transaction(
      id: isEdit ? widget.transaction!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      merchant: merchant,
      amount: amount,
      category: _selectedCategory,
      date: _selectedDate,
      isDebit: true,
      rawSms: isEdit ? widget.transaction!.rawSms : null,
      isManual: isEdit ? widget.transaction!.isManual : true,
    );

    // Learn from user
    _history.learn(merchant, _selectedCategory);

    widget.onSave(newTx, widget.index);
    Navigator.pop(context);
  }

  void _duplicate() {
    final merchant = _merchantController.text.trim();
    final amountText = _amountController.text.trim();

    if (merchant.isEmpty || amountText.isEmpty) {
      _showError('Missing Fields', 'Please enter both merchant name and amount.');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Invalid Amount', 'Please enter a valid amount greater than 0.');
      return;
    }

    final duplicate = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      merchant: merchant,
      amount: amount,
      category: _selectedCategory,
      date: DateTime.now(),
      isDebit: true,
      rawSms: null,
      isManual: true,
    );

    _history.learn(merchant, _selectedCategory);
    widget.onSave(duplicate, null);
    Navigator.pop(context);
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
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
              // Amount FIRST (reduced cognitive load)
              TextField(
                controller: _amountController,
                autofocus: !isEdit, // Auto-focus on amount for new entries
                decoration: const InputDecoration(
                  labelText: 'Amount (₹) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              // Merchant SECOND
              TextField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                onChanged: (val) {
                  if (val.trim().isNotEmpty) {
                    final predicted = _history.predictCategory(val.trim());
                    if (predicted != null) {
                      setState(() {
                        _categoryHint = 'Usually $predicted';
                        _selectedCategory = predicted;
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              // Category THIRD with hint
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category),
                  helperText: _categoryHint,
                  helperStyle: TextStyle(
                    color: Colors.blue.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                items: CATEGORIES.map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat),
                )).toList(),
                onChanged: (val) => setState(() {
                  _selectedCategory = val!;
                  _categoryHint = null;
                }),
              ),
              const SizedBox(height: 16),
              // Date collapsed to chip (expandable)
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Today'),
                    selected: _isToday(_selectedDate),
                    onSelected: (_) => setState(() => _selectedDate = DateTime.now()),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Yesterday'),
                    selected: _isYesterday(_selectedDate),
                    onSelected: (_) => setState(() => _selectedDate = DateTime.now().subtract(const Duration(days: 1))),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_isToday(_selectedDate) || _isYesterday(_selectedDate) ? 'Custom' : '${_selectedDate.day}/${_selectedDate.month}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (isEdit) ...[
                    TextButton(
                      onPressed: () {
                        widget.onSave(widget.transaction!, widget.index);
                        Navigator.pop(context);
                      },
                      child: const Text('DELETE', style: TextStyle(color: Colors.red)),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _duplicate,
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
                    onPressed: _validateAndSave,
                    child: Text(isEdit ? 'SAVE' : 'ADD'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}