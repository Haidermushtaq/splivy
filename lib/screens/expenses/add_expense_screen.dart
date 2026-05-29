import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../providers/groups_provider.dart';
import '../../services/expenses_service.dart';

class _GuestEntry {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController amountCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    amountCtrl.dispose();
  }
}

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

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() =>
      _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  static const _accent = Color(0xFF00D4AA);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'Food';
  int _selectedPayerIndex = 0;
  List<bool> _splitSelected = [];
  bool _customExpenseMode = false;
  final List<_GuestEntry> _guests = [];
  bool _isLoading = false;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    for (final g in _guests) {
      g.dispose();
    }
    super.dispose();
  }

  void _initSelections(List<GroupMember> members) {
    if (_splitSelected.length != members.length) {
      _splitSelected = List.filled(members.length, true);
      _selectedPayerIndex = members.indexWhere(
        (m) => m.id == _currentUserId,
      );
      if (_selectedPayerIndex < 0) _selectedPayerIndex = 0;
    }
  }

  double get _guestTotal {
    double total = 0;
    for (final g in _guests) {
      total += double.tryParse(g.amountCtrl.text) ?? 0;
    }
    return total;
  }

  double _splitAmount(int memberCount) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final count = _splitSelected.where((s) => s).length;
    final remaining = amount - (_customExpenseMode ? _guestTotal : 0);
    if (count == 0 || remaining <= 0) return 0;
    return remaining / count;
  }

  Future<void> _onSubmit(List<GroupMember> members) async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors above');
      return;
    }

    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0;
    final selectedCount = _splitSelected.where((s) => s).length;

    if (selectedCount == 0) {
      _showSnackBar('Please select at least one member for the split');
      return;
    }

    List<GuestSplitInput> guestInputs = [];
    double guestTotal = 0;

    if (_customExpenseMode && _guests.isNotEmpty) {
      for (final g in _guests) {
        final name = g.nameCtrl.text.trim();
        final phone = g.phoneCtrl.text.trim();
        final amt = double.tryParse(g.amountCtrl.text) ?? 0;
        if (name.isEmpty || phone.isEmpty || amt <= 0) {
          _showSnackBar('Please fill in all guest fields');
          return;
        }
        if (!RegExp(r'^03\d{9}$').hasMatch(phone)) {
          _showSnackBar('Guest phone must be in format 03XXXXXXXXX');
          return;
        }
        guestTotal += amt;
        guestInputs.add(GuestSplitInput(
          guestName: name,
          guestPhone: phone,
          amount: amt,
        ));
      }
      if (guestTotal >= amount) {
        _showSnackBar('Guest amounts must be less than total expense amount');
        return;
      }
    }

    final remaining = amount - guestTotal;
    final perPerson = remaining / selectedCount;
    final splits = <String, double>{};
    for (int i = 0; i < members.length; i++) {
      if (_splitSelected[i]) {
        splits[members[i].id] = perPerson;
      }
    }

    setState(() => _isLoading = true);
    try {
      await ExpensesService().addExpense(
        groupId: widget.groupId,
        title: title,
        amount: amount,
        category: _selectedCategory,
        paidBy: members[_selectedPayerIndex].id,
        splits: splits,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        guestSplits: guestInputs,
      );
      if (mounted) {
        _showSnackBar('Expense added!', isSuccess: true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to add expense: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isSuccess ? _accent : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showGuestDialog() {
    final cardColor = Theme.of(context).cardColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Outside Person',
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface,
              fontWeight: FontWeight.bold),
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
            onPressed: () => Navigator.of(ctx).pop(),
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
              setState(() {
                _customExpenseMode = true;
                if (_guests.isEmpty) _guests.add(_GuestEntry());
              });
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

  InputDecoration _fieldDecoration(
      {required String hint, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, size: 20),
      filled: true,
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
      errorStyle: const TextStyle(
        color: Color(0xFFFF6B6B),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2),
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
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Add Expense'),
        actions: [
          detailAsync.when(
            data: (detail) => IconButton(
              icon: const Icon(Icons.check_rounded, color: _accent),
              onPressed:
                  _isLoading ? null : () => _onSubmit(detail.members),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading group: $e',
              style: const TextStyle(color: Colors.grey)),
        ),
        data: (detail) {
          final members = detail.members;
          _initSelections(members);

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExpenseDetailsSection(onSurface),
                  const SizedBox(height: 24),
                  _buildPaidBySection(members),
                  const SizedBox(height: 24),
                  _buildSplitSection(members, onSurface),
                  const SizedBox(height: 24),
                  _buildGuestSection(onSurface),
                  const SizedBox(height: 24),
                  _buildNoteSection(onSurface),
                  const SizedBox(height: 32),
                  _buildSubmitButton(members),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpenseDetailsSection(Color onSurface) {
    final cardColor = Theme.of(context).cardColor;
    final fillColor = Theme.of(context).inputDecorationTheme.fillColor ??
        const Color(0xFF0F3460);
    final selectedCat =
        _categories.firstWhere((c) => c.name == _selectedCategory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Expense Details'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _titleController,
          style: TextStyle(color: onSurface),
          decoration: _fieldDecoration(
            hint: 'What was this expense for?',
            prefixIcon: Icons.edit_outlined,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Expense title is required';
            }
            if (value.trim().length < 2) {
              return 'Title must be at least 2 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amountController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'^\d+\.?\d{0,2}')),
          ],
          style: TextStyle(color: onSurface),
          onChanged: (_) => setState(() {}),
          decoration: _fieldDecoration(
            hint: 'Amount in PKR',
            prefixIcon: Icons.currency_rupee,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Amount is required';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Enter a valid amount greater than 0';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(selectedCat.icon, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: cardColor,
                  isExpanded: true,
                  underline: const SizedBox(),
                  style: TextStyle(color: onSurface),
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
                              style: TextStyle(color: onSurface)),
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

  Widget _buildPaidBySection(List<GroupMember> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Paid By'),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            itemBuilder: (_, index) {
              final isSelected = _selectedPayerIndex == index;
              final member = members[index];
              final displayName = member.id == _currentUserId
                  ? 'You'
                  : member.fullName.split(' ').first;
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
                          backgroundColor: isSelected
                              ? _accent
                              : Theme.of(context).cardColor,
                          child: Text(
                            member.fullName[0].toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        displayName,
                        style: TextStyle(
                          color:
                              isSelected ? _accent : Colors.grey,
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

  Widget _buildSplitSection(
      List<GroupMember> members, Color onSurface) {
    final splitAmt = _splitAmount(members.length);
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
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: List.generate(members.length, (index) {
              final isLast = index == members.length - 1;
              return Column(
                children: [
                  _buildMemberCheckRow(
                      index, members[index], onSurface),
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
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildMemberCheckRow(
      int index, GroupMember member, Color onSurface) {
    final displayName = member.id == _currentUserId
        ? 'You'
        : member.fullName.split(' ').first;
    return InkWell(
      onTap: () => setState(
          () => _splitSelected[index] = !_splitSelected[index]),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _accent,
              child: Text(
                member.fullName[0].toUpperCase(),
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
                displayName,
                style: TextStyle(color: onSurface, fontSize: 14),
              ),
            ),
            Checkbox(
              value: _splitSelected.length > index
                  ? _splitSelected[index]
                  : true,
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

  Widget _buildGuestSection(Color onSurface) {
    final fillColor =
        Theme.of(context).inputDecorationTheme.fillColor ??
            const Color(0xFF0F3460);
    final cardColor = Theme.of(context).cardColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_customExpenseMode) ...[
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
                color: fillColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: cardColor,
                    child: const Icon(Icons.person_add_outlined,
                        color: _accent, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text('Add a guest',
                      style:
                          TextStyle(color: onSurface, fontSize: 14)),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),
        ] else ...[
          _sectionLabel('Guest Splits'),
          const SizedBox(height: 4),
          const Text(
            'Enter name, phone (03XXXXXXXXX) and amount owed',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ...List.generate(_guests.length, (i) {
            final g = _guests[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Guest ${i + 1}',
                        style: const TextStyle(
                            color: _accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_guests.length > 1)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              g.dispose();
                              _guests.removeAt(i);
                            });
                          },
                          child: const Icon(Icons.close,
                              color: Colors.grey, size: 18),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: g.nameCtrl,
                    style: TextStyle(color: onSurface, fontSize: 13),
                    decoration: _fieldDecoration(
                        hint: 'Guest name',
                        prefixIcon: Icons.person_outline),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: g.phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: onSurface, fontSize: 13),
                    decoration: _fieldDecoration(
                        hint: '03XXXXXXXXX',
                        prefixIcon: Icons.phone_outlined),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: g.amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: onSurface, fontSize: 13),
                    decoration: _fieldDecoration(
                        hint: 'Amount they owe (PKR)',
                        prefixIcon: Icons.currency_rupee),
                  ),
                ],
              ),
            );
          }),
          if (_guestTotal > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_outlined,
                      color: Colors.amber, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Guest total: PKR ${_guestTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Colors.amber, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _guests.add(_GuestEntry()));
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _accent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            ),
            icon: const Icon(Icons.add, color: _accent, size: 16),
            label: const Text('Add Another Guest',
                style: TextStyle(color: _accent, fontSize: 13)),
          ),
        ],
      ],
    );
  }

  Widget _buildNoteSection(Color onSurface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Note'),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          style: TextStyle(color: onSurface),
          maxLines: 2,
          decoration: _fieldDecoration(
            hint: 'Add a note (optional)',
            prefixIcon: Icons.notes_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(List<GroupMember> members) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _onSubmit(members),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 2.5),
              )
            : const Text(
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
