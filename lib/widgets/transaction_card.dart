import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
    this.onDuplicate,
    this.onDelete,
  });

  IconData get _categoryIcon {
    switch (transaction.category) {
      case 'Food':
        return Icons.restaurant;
      case 'Grocery':
        return Icons.local_grocery_store;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Travel':
        return Icons.flight;
      case 'Utilities':
        return Icons.bolt;
      case 'Entertainment':
        return Icons.movie;
      case 'Health':
        return Icons.local_hospital;
      case 'Transfer':
        return Icons.swap_horiz;
      case 'Rent':
        return Icons.home;
      case 'Education':
        return Icons.school;
      default:
        return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = transaction;

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Right swipe = Duplicate
          onDuplicate?.call();
          return false; // Don't remove from list
        } else {
          // Left swipe = Delete with undo
          final deleted = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete Transaction?'),
              content: Text('Remove ₹${tx.amount.toStringAsFixed(0)} at ${tx.merchant}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('DELETE', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (deleted == true) {
            onDelete?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deleted ₹${tx.amount.toStringAsFixed(0)} at ${tx.merchant}'),
                action: SnackBarAction(
                  label: 'UNDO',
                  onPressed: () {
                    // Parent should handle undo via onSave
                  },
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return false;
        }
      },
      background: Container(
        color: Colors.blue.shade100,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.copy, color: Colors.blue.shade700),
      ),
      secondaryBackground: Container(
        color: Colors.red.shade100,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.red.shade700),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade100,
            child: Icon(_categoryIcon, color: Colors.grey.shade700),
          ),
          title: Text(tx.merchant, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${tx.category} • ${_formatDate(tx.date)}'),
          trailing: Text(
            '-₹${tx.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          onTap: onTap,
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