import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
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
        onTap: onTap,
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