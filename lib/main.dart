import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UPI Tracker',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}

class Transaction {
  String merchant;
  double amount;
  String category;
  DateTime date;
  bool isDebit;
  String rawSms;

  Transaction({
    required this.merchant,
    required this.amount,
    required this.category,
    required this.date,
    this.isDebit = true,
    required this.rawSms,
  });

  Map toJson() {
    return {
      'merchant': merchant,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'isDebit': isDebit,
      'rawSms': rawSms,
    };
  }

  static Transaction fromJson(Map json) {
    return Transaction(
      merchant: json['merchant'],
      amount: json['amount'],
      category: json['category'],
      date: DateTime.parse(json['date']),
      isDebit: json['isDebit'],
      rawSms: json['rawSms'],
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State {
  static const platform = MethodChannel('com.upitracker/sms');
  List transactions = [];
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initStorage();
   platform.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final body = call.arguments['body'] as String;
        final tx = _parseSms(body);
        
        // Only track debits (money spent), ignore credits
        if (tx.isDebit) {
          setState(() {
            transactions.insert(0, tx);
          });
          _saveTransactions();
        }
      }
    });

  }

  Future<void> _initStorage() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getString('transactions');
    if (saved != null) {
      final list = jsonDecode(saved) as List;
      setState(() {
        transactions = list.map((item) => Transaction.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveTransactions() async {
    final list = transactions.map((tx) => (tx as Transaction).toJson()).toList();
    await _prefs?.setString('transactions', jsonEncode(list));
  }
 
  Transaction _parseSms(String body) {
  final lower = body.toLowerCase();
  
  // Only process UPI-related SMS
  final isUPI = lower.contains('upi') || 
                lower.contains('debited') || 
                lower.contains('credited') ||
                lower.contains('inr') || 
                lower.contains('rs.') ||
                lower.contains('trf') ||
                lower.contains('transfer');
  
  if (!isUPI) {
    return Transaction(
      merchant: 'Ignored',
      amount: 0,
      category: 'Non-UPI',
      date: DateTime.now(),
      isDebit: true,
      rawSms: body,
    );
  }
  
  final isDebit = !lower.contains('credited') && !lower.contains('received');

  // Extract amount - handles all bank formats
  final amountPatterns = [
    // Standard: Rs. 500, INR 500, ₹500
    RegExp(r'(?:inr|rs\.?|₹)\s*([\d,]+\.?\d{0,2})\b', caseSensitive: false),
    // SBI: debited by 600.00
    RegExp(r'(?:debited|credited|received|paid|sent)\s+(?:by|for|of|with)?\s*([\d,]+\.?\d{0,2})\b', caseSensitive: false),
    // Axis/ICICI: towards Spotify for INR 59
    RegExp(r'(?:for|of)\s+(?:inr|rs\.?|₹)?\s*([\d,]+\.?\d{0,2})\b', caseSensitive: false),
    // Fallback: any number before UPI/on/via/to
    RegExp(r'\b([\d,]+\.?\d{0,2})\b(?=\s*(?:on|via|upi|to|from|trf|transfer|date))', caseSensitive: false),
  ];

  double amount = 0;
  for (final pattern in amountPatterns) {
    final match = pattern.firstMatch(body);
    if (match != null) {
      final parsed = double.tryParse(
        match.group(1)?.replaceAll(',', '') ?? '0'
      ) ?? 0;
      if (parsed > 0) {
        amount = parsed;
        break;
      }
    }
  }
  
  // Sanity check
  if (amount > 100000 || amount == 0) {
    return Transaction(
      merchant: 'Invalid',
      amount: amount,
      category: 'Parse Error',
      date: DateTime.now(),
      isDebit: isDebit,
      rawSms: body,
    );
  }

  // Extract merchant - handles all formats
  String merchant = 'Unknown';
  final merchantPatterns = [
    // SBI: trf to ISSHITA KALIA
    RegExp(r'(?:trf|transfer)\s+to\s+([A-Za-z][A-Za-z0-9\s&]+?)(?:\s+Ref|\s+If|\s+for|\s+via|$)', caseSensitive: false),
    // Standard: towards Spotify India
    RegExp(r'towards\s+([A-Za-z][A-Za-z0-9\s&]+?)(?:\s+for|\s+via|\s+UPI|\s+on|\s+\d)', caseSensitive: false),
    // Generic: to/from Name
    RegExp(r'(?:to|from)\s*:?\s*([A-Za-z][A-Za-z0-9\s&]+?)(?:\s+for|\s+via|\s+UPI|\s+Ref|\s+If)', caseSensitive: false),
  ];
  
  for (final pattern in merchantPatterns) {
    final match = pattern.firstMatch(body);
    if (match != null) {
      merchant = match.group(1)?.trim() ?? 'Unknown';
      if (merchant.isNotEmpty && merchant != 'Unknown') break;
    }
  }

  // Detect category
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
    merchant: merchant,
    amount: amount,
    category: category,
    date: DateTime.now(),
    isDebit: isDebit,
    rawSms: body,
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('UPI Tracker'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () async {
              setState(() => transactions.clear());
              await _prefs?.remove('transactions');
            },
          ),
        ],
      ),
      body: transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sms_failed, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No transactions yet', style: TextStyle(fontSize: 18)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index] as Transaction;
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    onTap: () => _showDetail(tx),
                  ),
                );
              },
            ),
    );
  }

  void _showDetail(Transaction tx) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tx.merchant, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('₹${tx.amount.toStringAsFixed(2)}', style: TextStyle(
              fontSize: 32,
              color: tx.isDebit ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 16),
            Text('Category: ${tx.category}'),
            Text('Date: ${_formatDate(tx.date)}'),
            SizedBox(height: 16),
            Text('Raw SMS:', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: Text(tx.rawSms, style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
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