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

class _MemberEntry {
  final String id;
  final String name;
  final TextEditingController paidController = TextEditingController(text: '0');
  final TextEditingController owedController = TextEditingController(text: '0');
  bool includedInSplit = true;

  _MemberEntry({required this.id, required this.name});

  void dispose() {
    paidController.dispose();
    owedController.dispose();
  }

  double get paidAmount => double.tryParse(paidController.text) ?? 0;
  double get owedAmount => double.tryParse(owedController.text) ?? 0;
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
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  static const _accent = Color(0xFF00D4AA);
  static const _cardColor = Color(0xFF0F3460);
  static const _red = Color(0xFFFF6B6B);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _scrollController = ScrollController();

  String _selectedCategory = 'Food';
  bool _isMultiPayer = false;
  bool _isCustomSplit = false;
  int _selectedPayerIndex = 0;
  List<_MemberEntry> _memberEntries = [];
  bool _customExpenseMode = false;
  final List<_GuestEntry> _guests = [];
  bool _isLoading = false;
  String _payerErrorMessage = '';
  String _splitErrorMessage = '';
  bool _summaryExpanded = true;
  bool _membersInitialized = false;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  double get _totalAmount => double.tryParse(_amountController.text) ?? 0;

  double get _totalPaid =>
      _memberEntries.fold(0.0, (sum, m) => sum + m.paidAmount);

  double get _totalOwed =>
      _memberEntries.where((m) => m.includedInSplit).fold(0.0, (sum, m) => sum + m.owedAmount);

  int get _splitCount => _memberEntries.where((m) => m.includedInSplit).length;

  double get _guestTotal {
    double total = 0;
    for (final g in _guests) {
      total += double.tryParse(g.amountCtrl.text) ?? 0;
    }
    return total;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _scrollController.dispose();
    for (final g in _guests) {
      g.dispose();
    }
    for (final m in _memberEntries) {
      m.dispose();
    }
    super.dispose();
  }

  void _initMembers(List<GroupMember> members) {
    if (_membersInitialized) return;
    _membersInitialized = true;

    _memberEntries = members.map((m) {
      final isCurrentUser = m.id == _currentUserId;
      return _MemberEntry(
        id: m.id,
        name: isCurrentUser ? 'You' : m.fullName,
      );
    }).toList();

    _selectedPayerIndex = _memberEntries.indexWhere(
      (m) => m.id == _currentUserId,
    );
    if (_selectedPayerIndex < 0) _selectedPayerIndex = 0;
  }

  void _updateEqualSplits() {
    if (_isCustomSplit || _totalAmount <= 0) return;
    final remaining = _totalAmount - (_customExpenseMode ? _guestTotal : 0);
    if (_splitCount == 0 || remaining <= 0) return;
    final perPerson = remaining / _splitCount;
    for (final m in _memberEntries) {
      if (m.includedInSplit) {
        m.owedController.text = perPerson.toStringAsFixed(2);
      } else {
        m.owedController.text = '0';
      }
    }
  }

  void _validatePayerAmounts() {
    if (!_isMultiPayer) {
      _payerErrorMessage = '';
      return;
    }
    if (_totalAmount <= 0) {
      _payerErrorMessage = '';
      return;
    }
    final diff = _totalPaid - _totalAmount;
    if (diff.abs() < 0.01) {
      _payerErrorMessage = '';
    } else if (diff < 0) {
      _payerErrorMessage =
          'Payer amounts (PKR ${_totalPaid.toStringAsFixed(0)}) don\'t match total bill (PKR ${_totalAmount.toStringAsFixed(0)}).\nNeed PKR ${diff.abs().toStringAsFixed(0)} more.';
    } else {
      _payerErrorMessage =
          'Payer amounts (PKR ${_totalPaid.toStringAsFixed(0)}) exceed total bill (PKR ${_totalAmount.toStringAsFixed(0)}).\nPKR ${diff.toStringAsFixed(0)} over budget.';
    }
  }

  void _validateSplitAmounts() {
    if (!_isCustomSplit) {
      _splitErrorMessage = '';
      return;
    }
    final targetAmount = _totalAmount - (_customExpenseMode ? _guestTotal : 0);
    if (targetAmount <= 0) {
      _splitErrorMessage = '';
      return;
    }
    final diff = _totalOwed - targetAmount;
    if (diff.abs() < 0.01) {
      _splitErrorMessage = '';
    } else {
      _splitErrorMessage =
          'Split amounts (PKR ${_totalOwed.toStringAsFixed(0)}) don\'t match total bill (PKR ${targetAmount.toStringAsFixed(0)}).\nDifference: PKR ${diff.abs().toStringAsFixed(0)}';
    }
  }

  List<Map<String, dynamic>> _calculateSettlements() {
    final Map<String, double> net = {};
    final Map<String, String> names = {};

    for (final m in _memberEntries) {
      names[m.id] = m.name;
      double paid = 0;
      double owed = 0;

      if (_isMultiPayer) {
        paid = m.paidAmount;
      } else if (_memberEntries.indexOf(m) == _selectedPayerIndex) {
        paid = _totalAmount;
      }

      if (m.includedInSplit) {
        owed = m.owedAmount;
      }

      net[m.id] = (net[m.id] ?? 0) + paid - owed;
    }

    final debtors = net.entries.where((e) => e.value < -0.01).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final creditors = net.entries.where((e) => e.value > 0.01).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<Map<String, dynamic>> settlements = [];
    int di = 0, ci = 0;
    final debtorValues = debtors.map((e) => e.value).toList();
    final creditorValues = creditors.map((e) => e.value).toList();

    while (di < debtors.length && ci < creditors.length) {
      final debtorId = debtors[di].key;
      final creditorId = creditors[ci].key;
      final amount = [debtorValues[di].abs(), creditorValues[ci]].reduce((a, b) => a < b ? a : b);

      if (amount > 0.01) {
        settlements.add({
          'from': debtorId,
          'fromName': names[debtorId],
          'to': creditorId,
          'toName': names[creditorId],
          'amount': amount,
        });
      }

      debtorValues[di] += amount;
      creditorValues[ci] -= amount;

      if (debtorValues[di].abs() < 0.01) di++;
      if (creditorValues[ci].abs() < 0.01) ci++;
    }

    return settlements;
  }

  Future<void> _onSubmit(List<GroupMember> members) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _validatePayerAmounts();
      _validateSplitAmounts();
    });

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors above');
      return;
    }

    if (_splitCount == 0) {
      _showSnackBar('Please select at least one member for the split');
      return;
    }

    if (_isMultiPayer && _payerErrorMessage.isNotEmpty) {
      _showSnackBar('Please fix payer amounts');
      return;
    }

    if (_isCustomSplit && _splitErrorMessage.isNotEmpty) {
      _showSnackBar('Please fix split amounts');
      return;
    }

    List<GuestSplitInput> guestInputs = [];
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
        guestInputs.add(GuestSplitInput(
          guestName: name,
          guestPhone: phone,
          amount: amt,
        ));
      }
    }

    final payerAmounts = _memberEntries
        .where((m) => m.paidAmount > 0)
        .map((m) => {'userId': m.id, 'amountPaid': m.paidAmount})
        .toList();

    final splitAmounts = _memberEntries
        .where((m) => m.includedInSplit)
        .map((m) => {'userId': m.id, 'amountOwed': m.owedAmount})
        .toList();

    setState(() => _isLoading = true);
    try {
      await ExpensesService().addExpenseV2(
        groupId: widget.groupId,
        title: _titleController.text.trim(),
        totalAmount: _totalAmount,
        isMultiPayer: _isMultiPayer,
        singlePayerId: _isMultiPayer ? null : _memberEntries[_selectedPayerIndex].id,
        payerAmounts: _isMultiPayer ? payerAmounts : [],
        splitAmounts: splitAmounts,
        isEqualSplit: !_isCustomSplit,
        category: _selectedCategory,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        isCustom: _customExpenseMode,
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
        backgroundColor: isSuccess ? _accent : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showGuestDialog() {
    final cardColor = Theme.of(context).cardColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Outside Person',
          style: TextStyle(
            color: Theme.of(ctx).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Create a new Group with them', style: TextStyle(color: _accent)),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint, required IconData prefixIcon}) {
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
      errorStyle: const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w500),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _accent,
        fontSize: 14,
        fontWeight: FontWeight.bold,
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
              onPressed: _isLoading ? null : () => _onSubmit(detail.members),
            ),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading group: $e', style: const TextStyle(color: Colors.grey)),
        ),
        data: (detail) {
          final members = detail.members;
          _initMembers(members);

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildExpenseDetailsSection(onSurface),
                    const SizedBox(height: 24),
                    _buildWhoPaidSection(onSurface),
                    const SizedBox(height: 24),
                    _buildSplitSection(onSurface),
                    const SizedBox(height: 24),
                    _buildSettlementPreview(onSurface),
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
    final fillColor = Theme.of(context).inputDecorationTheme.fillColor ?? _cardColor;
    final selectedCat = _categories.firstWhere((c) => c.name == _selectedCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Expense Details'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _titleController,
          style: TextStyle(color: onSurface),
          decoration: _fieldDecoration(hint: 'What was this expense for?', prefixIcon: Icons.edit_outlined),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Expense title is required';
            if (value.trim().length < 2) return 'Title must be at least 2 characters';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          style: TextStyle(color: onSurface),
          onChanged: (_) {
            setState(() {
              _updateEqualSplits();
              _validatePayerAmounts();
              _validateSplitAmounts();
            });
          },
          decoration: _fieldDecoration(hint: 'Total Amount (PKR)', prefixIcon: Icons.currency_rupee),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Amount is required';
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) return 'Enter a valid amount greater than 0';
            return null;
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(12)),
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
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.name,
                      child: Row(
                        children: [
                          Icon(cat.icon, color: _accent, size: 18),
                          const SizedBox(width: 10),
                          Text(cat.name, style: TextStyle(color: onSurface)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWhoPaidSection(Color onSurface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Who Paid?'),
        const SizedBox(height: 12),
        Row(
          children: [
            _modeChip('Single Payer', isSelected: !_isMultiPayer, onTap: () {
              setState(() {
                _isMultiPayer = false;
                _payerErrorMessage = '';
              });
            }),
            const SizedBox(width: 10),
            _modeChip('Multiple Payers', isSelected: _isMultiPayer, onTap: () {
              setState(() {
                _isMultiPayer = true;
                _validatePayerAmounts();
              });
            }),
          ],
        ),
        const SizedBox(height: 14),
        if (!_isMultiPayer) _buildSinglePayerSelector(onSurface) else _buildMultiPayerList(onSurface),
      ],
    );
  }

  Widget _modeChip(String label, {required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _accent : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSinglePayerSelector(Color onSurface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _memberEntries.length,
            itemBuilder: (_, index) {
              final isSelected = _selectedPayerIndex == index;
              final member = _memberEntries[index];
              final displayName = member.name.split(' ').first;
              return GestureDetector(
                onTap: () => setState(() => _selectedPayerIndex = index),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? _accent : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: isSelected ? _accent : Theme.of(context).cardColor,
                          child: Text(
                            member.name[0].toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.grey,
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
                          color: isSelected ? _accent : Colors.grey,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_selectedPayerIndex >= 0 && _selectedPayerIndex < _memberEntries.length)
          Text(
            'Paying: ${_memberEntries[_selectedPayerIndex].name}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildMultiPayerList(Color onSurface) {
    final fillColor = Theme.of(context).inputDecorationTheme.fillColor ?? _cardColor;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _memberEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              final isLast = index == _memberEntries.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: _accent,
                          child: Text(
                            member.name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(member.name, style: TextStyle(color: onSurface, fontSize: 14)),
                        ),
                        const Text('PKR ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: member.paidController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            textAlign: TextAlign.center,
                            style: TextStyle(color: onSurface, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '0',
                              filled: true,
                              fillColor: fillColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (_) {
                              setState(() => _validatePayerAmounts());
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(color: Colors.white12, height: 1, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _buildPayerTotalCard(),
        if (_payerErrorMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_payerErrorMessage, style: const TextStyle(color: _red, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildPayerTotalCard() {
    final diff = _totalPaid - _totalAmount;
    final isMatched = diff.abs() < 0.01;
    final isOver = diff > 0.01;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Paid: PKR ${_totalPaid.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (isMatched)
            const Row(
              children: [
                Icon(Icons.check_circle, color: _accent, size: 16),
                SizedBox(width: 4),
                Text('Matched!', style: TextStyle(color: _accent, fontWeight: FontWeight.bold)),
              ],
            )
          else
            Text(
              isOver ? 'PKR ${diff.toStringAsFixed(0)} over' : 'Need PKR ${diff.abs().toStringAsFixed(0)} more',
              style: const TextStyle(color: _red, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildSplitSection(Color onSurface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Split Between?'),
        const SizedBox(height: 12),
        Row(
          children: [
            _modeChip('Equal Split', isSelected: !_isCustomSplit, onTap: () {
              setState(() {
                _isCustomSplit = false;
                _updateEqualSplits();
                _splitErrorMessage = '';
              });
            }),
            const SizedBox(width: 10),
            _modeChip('Custom Split', isSelected: _isCustomSplit, onTap: () {
              setState(() {
                _isCustomSplit = true;
                _validateSplitAmounts();
              });
            }),
          ],
        ),
        const SizedBox(height: 14),
        if (!_isCustomSplit) _buildEqualSplitList(onSurface) else _buildCustomSplitList(onSurface),
      ],
    );
  }

  Widget _buildEqualSplitList(Color onSurface) {
    final targetAmount = _totalAmount - (_customExpenseMode ? _guestTotal : 0);
    final splitAmt = _splitCount > 0 && targetAmount > 0 ? targetAmount / _splitCount : 0.0;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _memberEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              final isLast = index == _memberEntries.length - 1;
              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        member.includedInSplit = !member.includedInSplit;
                        _updateEqualSplits();
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _accent,
                            child: Text(
                              member.name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(member.name, style: TextStyle(color: onSurface, fontSize: 14))),
                          Checkbox(
                            value: member.includedInSplit,
                            activeColor: _accent,
                            checkColor: Colors.black,
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) {
                              setState(() {
                                member.includedInSplit = val ?? false;
                                _updateEqualSplits();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast) const Divider(color: Colors.white12, height: 1, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
        if (splitAmt > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, color: _accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Each person pays: PKR ${splitAmt.toStringAsFixed(2)}',
                  style: const TextStyle(color: _accent, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '($_splitCount ${_splitCount == 1 ? 'person' : 'people'})',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomSplitList(Color onSurface) {
    final fillColor = Theme.of(context).inputDecorationTheme.fillColor ?? _cardColor;
    final targetAmount = _totalAmount - (_customExpenseMode ? _guestTotal : 0);

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _memberEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              final isLast = index == _memberEntries.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              member.includedInSplit = !member.includedInSplit;
                              if (!member.includedInSplit) {
                                member.owedController.text = '0';
                              }
                              _validateSplitAmounts();
                            });
                          },
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: member.includedInSplit ? _accent : Colors.grey,
                            child: Text(
                              member.name[0].toUpperCase(),
                              style: TextStyle(
                                color: member.includedInSplit ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            member.name,
                            style: TextStyle(
                              color: member.includedInSplit ? onSurface : Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              member.owedController.text = '0';
                              member.includedInSplit = false;
                              _validateSplitAmounts();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('0', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          ),
                        ),
                        const Text('PKR ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: member.owedController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            textAlign: TextAlign.center,
                            style: TextStyle(color: onSurface, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '0',
                              filled: true,
                              fillColor: fillColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                final amount = double.tryParse(val) ?? 0;
                                member.includedInSplit = amount > 0;
                                _validateSplitAmounts();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(color: Colors.white12, height: 1, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _buildSplitTotalCard(targetAmount),
        if (_splitErrorMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_splitErrorMessage, style: const TextStyle(color: _red, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildSplitTotalCard(double targetAmount) {
    final diff = _totalOwed - targetAmount;
    final isMatched = diff.abs() < 0.01 && targetAmount > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Assigned: PKR ${_totalOwed.toStringAsFixed(0)} of PKR ${targetAmount.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          if (isMatched)
            const Row(
              children: [
                Icon(Icons.check_circle, color: _accent, size: 16),
                SizedBox(width: 4),
                Text('Matched!', style: TextStyle(color: _accent, fontWeight: FontWeight.bold)),
              ],
            )
          else if (targetAmount > 0)
            Text(
              diff > 0 ? 'PKR ${diff.toStringAsFixed(0)} over' : 'PKR ${diff.abs().toStringAsFixed(0)} left',
              style: const TextStyle(color: _red, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildSettlementPreview(Color onSurface) {
    final settlements = _calculateSettlements();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  const Text(
                    'Settlement Preview',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(
                    _summaryExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_summaryExpanded) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: settlements.isEmpty
                  ? const Text(
                      'Enter amounts to see who pays whom',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Based on who paid and who owes:',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        ...settlements.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: _red.withValues(alpha: 0.2),
                                    child: Text(
                                      (s['fromName'] as String)[0],
                                      style: const TextStyle(color: _red, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(s['fromName'] as String, style: TextStyle(color: onSurface, fontSize: 12)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, color: Colors.grey, size: 14),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: _accent.withValues(alpha: 0.2),
                                    child: Text(
                                      (s['toName'] as String)[0],
                                      style: const TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(s['toName'] as String, style: TextStyle(color: onSurface, fontSize: 12)),
                                  const Spacer(),
                                  Text(
                                    'PKR ${(s['amount'] as double).toStringAsFixed(0)}',
                                    style: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuestSection(Color onSurface) {
    final fillColor = Theme.of(context).inputDecorationTheme.fillColor ?? _cardColor;
    final cardColor = Theme.of(context).cardColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_customExpenseMode) ...[
          const Text('Adding someone outside this group?', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 10),
          InkWell(
            onTap: _showGuestDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    child: const Icon(Icons.person_add_outlined, color: _accent, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text('Add a guest', style: TextStyle(color: onSurface, fontSize: 14)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
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
                      Text('Guest ${i + 1}', style: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_guests.length > 1)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              g.dispose();
                              _guests.removeAt(i);
                              _updateEqualSplits();
                            });
                          },
                          child: const Icon(Icons.close, color: Colors.grey, size: 18),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: g.nameCtrl,
                    style: TextStyle(color: onSurface, fontSize: 13),
                    decoration: _fieldDecoration(hint: 'Guest name', prefixIcon: Icons.person_outline),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: g.phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: onSurface, fontSize: 13),
                    decoration: _fieldDecoration(hint: '03XXXXXXXXX', prefixIcon: Icons.phone_outlined),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: g.amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    onChanged: (_) {
                      setState(() => _updateEqualSplits());
                    },
                    style: TextStyle(color: onSurface, fontSize: 13),
                    decoration: _fieldDecoration(hint: 'Amount they owe (PKR)', prefixIcon: Icons.currency_rupee),
                  ),
                ],
              ),
            );
          }),
          if (_guestTotal > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_outlined, color: Colors.amber, size: 14),
                  const SizedBox(width: 6),
                  Text('Guest total: PKR ${_guestTotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.amber, fontSize: 12)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => _guests.add(_GuestEntry())),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _accent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            ),
            icon: const Icon(Icons.add, color: _accent, size: 16),
            label: const Text('Add Another Guest', style: TextStyle(color: _accent, fontSize: 13)),
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
          decoration: _fieldDecoration(hint: 'Add a note (optional)', prefixIcon: Icons.notes_outlined),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
              )
            : const Text(
                'Add Expense',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
      ),
    );
  }
}
