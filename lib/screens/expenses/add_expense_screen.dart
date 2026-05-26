import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _Category {
  final String name;
  final IconData icon;
  const _Category(this.name, this.icon);
}

const _categories = [
  _Category('Food', Icons.restaurant_outlined),
  _Category('Transport', Icons.directions_car_outlined),
  _Category('Shopping', Icons.shopping_bag_outlined),
  _Category('Utilities', Icons.bolt_outlined),
  _Category('Entertainment', Icons.movie_outlined),
  _Category('Other', Icons.category_outlined),
];

const _members = ['Ali', 'Mohsin', 'You'];

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  static const _bg = Color(0xFF1A1A2E);
  static const _accent = Color(0xFF00D4AA);
  static const _cardDark = Color(0xFF0F3460);
  static const _fieldFill = Color(0xFF0A0A20);

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'Food';
  int _selectedPayerIndex = 2; // "You" by default
  final List<bool> _splitSelected = List.filled(_members.length, true);
  bool _customExpenseNote = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _splitAmount {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final count = _splitSelected.where((s) => s).length;
    if (count == 0 || amount == 0) return 0;
    return amount / count;
  }

  void _onSubmit() {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0;
    final selectedCount = _splitSelected.where((s) => s).length;

    if (title.isEmpty) {
      _showSnackBar('Please enter an expense title');
      return;
    }
    if (amountText.isEmpty || amount <= 0) {
      _showSnackBar('Please enter a valid amount');
      return;
    }
    if (selectedCount == 0) {
      _showSnackBar('Please select at least one member for the split');
      return;
    }

    // TODO: save to Supabase
    _showSnackBar('Expense added!', isSuccess: true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? _accent : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showGuestDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Outside Person',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'How would you like to handle this?',
          style: TextStyle(color: Colors.grey),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _accent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              // TODO: navigate to create group screen
            },
            child: const Text(
              'Create a new Group with them',
              style: TextStyle(color: _accent),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _customExpenseNote = true);
            },
            child: const Text(
              'Add as one-time custom expense',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(prefixIcon, color: Colors.grey, size: 20),
      filled: true,
      fillColor: _fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _accent,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Add Expense',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: _accent),
            onPressed: _onSubmit,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildExpenseDetailsSection(),
              const SizedBox(height: 24),
              _buildPaidBySection(),
              const SizedBox(height: 24),
              _buildSplitSection(),
              const SizedBox(height: 24),
              _buildGuestSection(),
              const SizedBox(height: 24),
              _buildNoteSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseDetailsSection() {
    final selectedCat =
        _categories.firstWhere((c) => c.name == _selectedCategory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Expense Details'),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration(
            hint: 'What was this expense for?',
            prefixIcon: Icons.edit_outlined,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          style: const TextStyle(color: Colors.white),
          onChanged: (_) => setState(() {}),
          decoration: _fieldDecoration(
            hint: 'Amount in PKR',
            prefixIcon: Icons.currency_rupee,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(selectedCat.icon, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: _cardDark,
                  isExpanded: true,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.grey),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.name,
                      child: Row(
                        children: [
                          Icon(cat.icon, color: _accent, size: 18),
                          const SizedBox(width: 10),
                          Text(cat.name,
                              style:
                                  const TextStyle(color: Colors.white)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaidBySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Paid By'),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _members.length,
            itemBuilder: (_, index) {
              final isSelected = _selectedPayerIndex == index;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedPayerIndex = index),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? _accent
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              isSelected ? _accent : _cardDark,
                          child: Text(
                            _members[index][0].toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _members[index],
                        style: TextStyle(
                          color: isSelected ? _accent : Colors.grey,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSplitSection() {
    final splitAmt = _splitAmount;
    final selectedCount = _splitSelected.where((s) => s).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Split Between'),
        const SizedBox(height: 12),
        Row(
          children: [
            _splitChip('Equal Split', active: true),
            const SizedBox(width: 10),
            _splitChip('Custom Split', active: false),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: _cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: List.generate(_members.length, (index) {
              final isLast = index == _members.length - 1;
              return Column(
                children: [
                  _buildMemberCheckRow(index),
                  if (!isLast)
                    const Divider(
                        color: Colors.white12,
                        height: 1,
                        indent: 16,
                        endIndent: 16),
                ],
              );
            }),
          ),
        ),
        if (splitAmt > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined,
                    color: _accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Each person pays: PKR ${splitAmt.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: _accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '($selectedCount ${selectedCount == 1 ? 'person' : 'people'})',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _splitChip(String label, {required bool active}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? _accent.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? _accent
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        active ? label : '$label  (soon)',
        style: TextStyle(
          color: active ? _accent : Colors.grey,
          fontSize: 12,
          fontWeight:
              active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildMemberCheckRow(int index) {
    return InkWell(
      onTap: () => setState(
          () => _splitSelected[index] = !_splitSelected[index]),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _accent,
              child: Text(
                _members[index][0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _members[index],
                style: const TextStyle(
                    color: Colors.white, fontSize: 14),
              ),
            ),
            Checkbox(
              value: _splitSelected[index],
              activeColor: _accent,
              checkColor: Colors.black,
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              onChanged: (val) => setState(
                  () => _splitSelected[index] = val ?? false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Adding someone outside this group?',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _showGuestDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _cardDark,
                  child: const Icon(Icons.person_add_outlined,
                      color: _accent, size: 16),
                ),
                const SizedBox(width: 12),
                const Text('Add a guest',
                    style:
                        TextStyle(color: Colors.white, fontSize: 14)),
                const Spacer(),
                const Icon(Icons.chevron_right,
                    color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
        if (_customExpenseNote) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.amber, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This can be archived once settled.',
                    style:
                        TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Note'),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: _fieldDecoration(
            hint: 'Add a note (optional)',
            prefixIcon: Icons.notes_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: const Text(
          'Add Expense',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
