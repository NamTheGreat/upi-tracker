import '../models/transaction.dart';

class SmsParser {
  Transaction? parse(String body) {
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
        final parsed = double.tryParse(match.group(1)?.replaceAll(',', '') ?? '0') ?? 0;
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
}