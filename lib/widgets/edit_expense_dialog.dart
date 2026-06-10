import 'package:flutter/material.dart';

const _accent = Color(0xFF00D4AA);
const _dialogBg = Color(0xFF0F3460);
const _field = Color(0xFF16213E);

const expenseCategories = [
  'Food',
  'Transport',
  'Shopping',
  'Utilities',
  'Entertainment',
  'Other',
];

/// The descriptive fields of an expense the user can edit in place.
class ExpenseMetaEdit {
  final String title;
  final String category;
  final String? note;

  const ExpenseMetaEdit({
    required this.title,
    required this.category,
    this.note,
  });
}

/// Shows the edit sheet for an expense's title, category, and note. Returns the
/// new values on save, or `null` if cancelled. Only descriptive fields are
/// editable here — amount and splits are not, since changing them would
/// invalidate already-settled balances.
Future<ExpenseMetaEdit?> showEditExpenseDialog(
  BuildContext context, {
  required String title,
  required String category,
  String? note,
}) {
  return showDialog<ExpenseMetaEdit>(
    context: context,
    builder: (_) => _EditExpenseDialog(
      title: title,
      category: category,
      note: note,
    ),
  );
}

class _EditExpenseDialog extends StatefulWidget {
  final String title;
  final String category;
  final String? note;

  const _EditExpenseDialog({
    required this.title,
    required this.category,
    this.note,
  });

  @override
  State<_EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends State<_EditExpenseDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late String _category;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.title);
    _noteCtrl = TextEditingController(text: widget.note ?? '');
    // The stored category may predate the current list; keep it selectable.
    _category = expenseCategories.contains(widget.category)
        ? widget.category
        : expenseCategories.last;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Title is required');
      return;
    }
    Navigator.pop(
      context,
      ExpenseMetaEdit(
        title: title,
        category: _category,
        note: _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.edit_outlined, color: _accent, size: 24),
          SizedBox(width: 8),
          Text(
            'Edit Expense',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Title', errorText: _titleError),
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            dropdownColor: _field,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Category'),
            items: expenseCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: _decoration('Note (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  InputDecoration _decoration(String label, {String? errorText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      errorText: errorText,
      filled: true,
      fillColor: _field,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent),
      ),
    );
  }
}
