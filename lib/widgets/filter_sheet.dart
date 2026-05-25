import 'package:flutter/material.dart';
import '../constants.dart';

class FilterSheet extends StatefulWidget {
  final String? initialCategory;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final Function(String?, DateTime?, DateTime?) onApply;
  final VoidCallback onClear;

  const FilterSheet({
    super.key,
    this.initialCategory,
    this.initialStartDate,
    this.initialEndDate,
    required this.onApply,
    required this.onClear,
  });

  @override
  State createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  String? _category;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            initialValue: _category,
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
            onChanged: (val) => setState(() => _category = val),
          ),
          const SizedBox(height: 16),
          _dateTile('Start Date', _startDate, (date) => setState(() => _startDate = date)),
          const SizedBox(height: 12),
          _dateTile('End Date', _endDate, (date) => setState(() => _endDate = date)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  widget.onClear();
                  Navigator.pop(context);
                },
                child: const Text('CLEAR ALL'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  widget.onApply(_category, _startDate, _endDate);
                  Navigator.pop(context);
                },
                child: const Text('APPLY'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, Function(DateTime) onPicked) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade400),
      ),
      leading: const Icon(Icons.date_range),
      title: Text(label),
      subtitle: Text(date != null ? '${date.day}/${date.month}/${date.year}' : 'Any'),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPicked(picked);
      },
    );
  }
}