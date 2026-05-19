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