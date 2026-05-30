import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/expense_model.dart';
import '../../models/friend_model.dart';
import '../../providers/friends_provider.dart';
import '../../services/expenses_service.dart';

/// A registered participant (the current user or a connected friend).
class _Participant {
  final String id;
  final String name;
  final bool isYou;
  final TextEditingController paidController = TextEditingController(text: '0');
  final TextEditingController owedController = TextEditingController(text: '0');
  bool includedInSplit = true;

  _Participant({required this.id, required this.name, this.isYou = false});

  double get paidAmount => double.tryParse(paidController.text) ?? 0;
  double get owedAmount => double.tryParse(owedController.text) ?? 0;

  void dispose() {
    paidController.dispose();
    owedController.dispose();
  }
}

class _GuestEntry {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController amountCtrl = TextEditingController(text: '0');
  final TextEditingController paidCtrl = TextEditingController(text: '0');

  double get amount => double.tryParse(amountCtrl.text) ?? 0;
  double get paidAmount => double.tryParse(paidCtrl.text) ?? 0;

  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    amountCtrl.dispose();
    paidCtrl.dispose();
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

class OneTimeExpenseScreen extends ConsumerStatefulWidget {
  const OneTimeExpenseScreen({super.key});

  @override
  ConsumerState<OneTimeExpenseScreen> createState() =>
      _OneTimeExpenseScreenState();
}

class _OneTimeExpenseScreenState extends ConsumerState<OneTimeExpenseScreen> {
  static const _accent = Color(0xFF00D4AA);
  static const _cardColor = Color(0xFF0F3460);
  static const _red = Color(0xFFFF6B6B);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'Food';
  bool _isMultiPayer = false;
  bool _isCustomSplit = false;
  int _selectedPayerIndex = 0;
  bool _isLoading = false;
  bool _summaryExpanded = true;
  String _payerErrorMessage = '';
  String _splitErrorMessage = '';

  final List<_Participant> _participants = [];
  final List<_GuestEntry> _guests = [];

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  double get _totalAmount => double.tryParse(_amountController.text) ?? 0;

  double get _guestTotal => _guests.fold(0.0, (s, g) => s + g.amount);

  double get _guestPaidTotal =>
      _guests.fold(0.0, (s, g) => s + g.paidAmount);


  double get _totalPaid =>
      _participants.fold(0.0, (s, p) => s + p.paidAmount) + _guestPaidTotal;

  double get _registeredOwed => _participants
      .where((p) => p.includedInSplit)
      .fold(0.0, (s, p) => s + p.owedAmount);

  int get _registeredSplitCount =>
      _participants.where((p) => p.includedInSplit).length;

  int get _splitCount => _registeredSplitCount + _guests.length;

  @override
  void initState() {
    super.initState();
    _participants.add(_Participant(id: _currentUserId, name: 'You', isYou: true));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    for (final p in _participants) {
      p.dispose();
    }
    for (final g in _guests) {
      g.dispose();
    }
    super.dispose();
  }

  void _recompute() {
    _updateEqualSplits();
    _validatePayerAmounts();
    _validateSplitAmounts();
  }

  void _updateEqualSplits() {
    if (_isCustomSplit || _totalAmount <= 0 || _splitCount == 0) return;
    final per = _totalAmount / _splitCount;
    final perStr = per.toStringAsFixed(2);
    for (final p in _participants) {
      p.owedController.text = p.includedInSplit ? perStr : '0';
    }
    for (final g in _guests) {
      g.amountCtrl.text = perStr;
    }
  }

  void _validatePayerAmounts() {
    if (!_isMultiPayer || _totalAmount <= 0) {
      _payerErrorMessage = '';
      return;
    }
    final diff = _totalPaid - _totalAmount;
    if (diff.abs() < 0.01) {
      _payerErrorMessage = '';
    } else if (diff < 0) {
      _payerErrorMessage =
          'Paid PKR ${_totalPaid.toStringAsFixed(0)} of PKR ${_totalAmount.toStringAsFixed(0)} — need PKR ${diff.abs().toStringAsFixed(0)} more.';
    } else {
      _payerErrorMessage =
          'Paid PKR ${_totalPaid.toStringAsFixed(0)} exceeds bill by PKR ${diff.toStringAsFixed(0)}.';
    }
  }

  void _validateSplitAmounts() {
    if (!_isCustomSplit || _totalAmount <= 0) {
      _splitErrorMessage = '';
      return;
    }
    final assigned = _registeredOwed + _guestTotal;
    final diff = assigned - _totalAmount;
    if (diff.abs() < 0.01) {
      _splitErrorMessage = '';
    } else {
      _splitErrorMessage =
          'Assigned PKR ${assigned.toStringAsFixed(0)} of PKR ${_totalAmount.toStringAsFixed(0)} — difference PKR ${diff.abs().toStringAsFixed(0)}.';
    }
  }

  List<Map<String, dynamic>> _calculateSettlements() {
    final Map<String, double> net = {};
    final Map<String, String> names = {};

    for (final p in _participants) {
      names[p.id] = p.name;
      double paid = 0;
      double owed = 0;
      if (_isMultiPayer) {
        paid = p.paidAmount;
      } else if (_participants.indexOf(p) == _selectedPayerIndex) {
        paid = _totalAmount;
      }
      if (p.includedInSplit) owed = p.owedAmount;
      net[p.id] = (net[p.id] ?? 0) + paid - owed;
    }

    for (var i = 0; i < _guests.length; i++) {
      final g = _guests[i];
      final key = 'guest_$i';
      final entered = g.nameCtrl.text.trim();
      names[key] = entered.isEmpty ? 'Guest ${i + 1}' : entered;
      final paid = _isMultiPayer ? g.paidAmount : 0.0;
      net[key] = (net[key] ?? 0) + paid - g.amount;
    }

    final debtors = net.entries.where((e) => e.value < -0.01).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final creditors = net.entries.where((e) => e.value > 0.01).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final dVals = debtors.map((e) => e.value).toList();
    final cVals = creditors.map((e) => e.value).toList();

    final settlements = <Map<String, dynamic>>[];
    int di = 0, ci = 0;
    while (di < debtors.length && ci < creditors.length) {
      final amount =
          [dVals[di].abs(), cVals[ci]].reduce((a, b) => a < b ? a : b);
      if (amount > 0.01) {
        settlements.add({
          'fromName': names[debtors[di].key],
          'toName': names[creditors[ci].key],
          'amount': amount,
        });
      }
      dVals[di] += amount;
      cVals[ci] -= amount;
      if (dVals[di].abs() < 0.01) di++;
      if (cVals[ci].abs() < 0.01) ci++;
    }
    return settlements;
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    setState(_recompute);

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors above');
      return;
    }
    if (_splitCount == 0) {
      _showSnackBar('Add at least one person to split with');
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

    final guestInputs = <GuestSplitInput>[];
    for (final g in _guests) {
      final name = g.nameCtrl.text.trim();
      final phone = g.phoneCtrl.text.trim();
      if (name.isEmpty || phone.isEmpty || g.amount <= 0) {
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
        amount: g.amount,
        amountPaid: _isMultiPayer ? g.paidAmount : 0,
      ));
    }

    final payerAmounts = _participants
        .where((p) => p.paidAmount > 0)
        .map((p) => {'userId': p.id, 'amountPaid': p.paidAmount})
        .toList();

    final splitAmounts = _participants
        .where((p) => p.includedInSplit && p.owedAmount > 0)
        .map((p) => {'userId': p.id, 'amountOwed': p.owedAmount})
        .toList();

    setState(() => _isLoading = true);
    try {
      await ExpensesService().addOneTimeExpense(
        title: _titleController.text.trim(),
        totalAmount: _totalAmount,
        isMultiPayer: _isMultiPayer,
        payerAmounts: _isMultiPayer ? payerAmounts : [],
        splitAmounts: splitAmounts,
        category: _selectedCategory,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        guestSplits: guestInputs,
      );
      if (mounted) {
        _showSnackBar('One-time expense added!', isSuccess: true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) Navigator.of(context).pop(true);
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

  void _showFriendPicker() {
    final friendsAsync = ref.read(friendsListProvider);
    final friends = friendsAsync.value ?? [];
    final available = friends
        .where((f) => !_participants.any((p) => p.id == f.friendId))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final onSurface = Theme.of(ctx).colorScheme.onSurface;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add a friend',
                    style: TextStyle(
                        color: onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (available.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No more friends to add. Connect with friends first, or add a guest instead.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                else
                  ...available.map((f) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _accent,
                          child: Text(
                            f.fullName[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(f.fullName,
                            style: TextStyle(color: onSurface)),
                        subtitle: Text('@${f.username}',
                            style: const TextStyle(color: Colors.grey)),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _addFriend(f);
                        },
                      )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addFriend(Friend f) {
    setState(() {
      _participants.add(_Participant(id: f.friendId, name: f.fullName));
      _recompute();
    });
  }

  void _removeParticipant(_Participant p) {
    setState(() {
      _participants.remove(p);
      p.dispose();
      if (_selectedPayerIndex >= _participants.length) _selectedPayerIndex = 0;
      _recompute();
    });
  }

  void _addGuest() {
    setState(() {
      _guests.add(_GuestEntry());
      _recompute();
    });
  }

  void _removeGuest(_GuestEntry g) {
    setState(() {
      _guests.remove(g);
      g.dispose();
      _recompute();
    });
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
      errorStyle:
          const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
          color: _accent, fontSize: 14, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('One-time Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: _accent),
            onPressed: _isLoading ? null : _onSubmit,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailsSection(onSurface),
                const SizedBox(height: 24),
                _buildPeopleSection(onSurface),
                const SizedBox(height: 24),
                _buildWhoPaidSection(onSurface),
                const SizedBox(height: 24),
                _buildSplitSection(onSurface),
                const SizedBox(height: 24),
                _buildSettlementPreview(onSurface),
                const SizedBox(height: 24),
                _buildNoteSection(onSurface),
                const SizedBox(height: 32),
                _buildSubmitButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection(Color onSurface) {
    final cardColor = Theme.of(context).cardColor;
    final fillColor =
        Theme.of(context).inputDecorationTheme.fillColor ?? _cardColor;
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
              prefixIcon: Icons.edit_outlined),
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
          ],
          style: TextStyle(color: onSurface),
          onChanged: (_) => setState(_recompute),
          decoration: _fieldDecoration(
              hint: 'Total Amount (PKR)', prefixIcon: Icons.currency_rupee),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
              color: fillColor, borderRadius: BorderRadius.circular(12)),
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

  Widget _buildPeopleSection(Color onSurface) {
    final cardColor = Theme.of(context).cardColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("Who's involved?"),
        const SizedBox(height: 4),
        const Text(
          'Add connected friends or one-time guests (name + phone).',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 12),
        // Registered participants
        Container(
          decoration: BoxDecoration(
              color: cardColor, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: _participants.map((p) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _accent,
                      child: Text(
                        p.name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(p.name,
                          style: TextStyle(color: onSurface, fontSize: 14)),
                    ),
                    if (p.isYou)
                      const Text('Payer by default',
                          style: TextStyle(color: Colors.grey, fontSize: 11))
                    else
                      GestureDetector(
                        onTap: () => _removeParticipant(p),
                        child: const Icon(Icons.close,
                            color: Colors.grey, size: 18),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        // Guests
        if (_guests.isNotEmpty) ...[
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
                      Text('Guest ${i + 1}',
                          style: const TextStyle(
                              color: _accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _removeGuest(g),
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
                        hint: 'Guest name', prefixIcon: Icons.person_outline),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: g.phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: onSurface, fontSize: 13),
                    decoration: _fieldDecoration(
                        hint: '03XXXXXXXXX', prefixIcon: Icons.phone_outlined),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showFriendPicker,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.person_add_alt_1,
                    color: _accent, size: 18),
                label: const Text('Add friend',
                    style: TextStyle(color: _accent, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addGuest,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.person_outline,
                    color: Colors.grey, size: 18),
                label: const Text('Add guest',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
          ],
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
        if (!_isMultiPayer)
          _buildSinglePayerSelector(onSurface)
        else
          _buildMultiPayerList(onSurface),
      ],
    );
  }

  Widget _modeChip(String label,
      {required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? _accent : Colors.grey.withValues(alpha: 0.3)),
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
            itemCount: _participants.length,
            itemBuilder: (_, index) {
              final isSelected = _selectedPayerIndex == index;
              final p = _participants[index];
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
                          backgroundColor: isSelected
                              ? _accent
                              : Theme.of(context).cardColor,
                          child: Text(
                            p.name[0].toUpperCase(),
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
                        p.name.split(' ').first,
                        style: TextStyle(
                          color: isSelected ? _accent : Colors.grey,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildMultiPayerList(Color onSurface) {
    final fillColor =
        Theme.of(context).inputDecorationTheme.fillColor ?? _cardColor;

    Widget paidRow({
      required String name,
      required Color avatarColor,
      required Color avatarTextColor,
      required TextEditingController controller,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarColor,
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(
                    color: avatarTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  style: TextStyle(color: onSurface, fontSize: 14)),
            ),
            const Text('PKR ',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            SizedBox(
              width: 80,
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                ],
                textAlign: TextAlign.center,
                style: TextStyle(color: onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '0',
                  filled: true,
                  fillColor: fillColor,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(_validatePayerAmounts),
              ),
            ),
          ],
        ),
      );
    }

    final rows = <Widget>[];
    for (final p in _participants) {
      rows.add(paidRow(
        name: p.name,
        avatarColor: _accent,
        avatarTextColor: Colors.black,
        controller: p.paidController,
      ));
    }
    for (var i = 0; i < _guests.length; i++) {
      final g = _guests[i];
      final label =
          g.nameCtrl.text.trim().isEmpty ? 'Guest ${i + 1}' : g.nameCtrl.text.trim();
      rows.add(paidRow(
        name: '$label (guest)',
        avatarColor: Colors.amber,
        avatarTextColor: Colors.black,
        controller: g.paidCtrl,
      ));
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i != rows.length - 1)
                  const Divider(
                      color: Colors.white12,
                      height: 1,
                      indent: 16,
                      endIndent: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTotalCard(
          label: 'Total Paid',
          assigned: _totalPaid,
        ),
        if (_payerErrorMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_payerErrorMessage,
              style: const TextStyle(color: _red, fontSize: 12)),
        ],
      ],
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
        _buildSplitList(onSurface),
      ],
    );
  }

  Widget _buildSplitList(Color onSurface) {
    final fillColor =
        Theme.of(context).inputDecorationTheme.fillColor ?? _cardColor;

    Widget amountField(TextEditingController ctrl, {required bool enabled}) {
      return SizedBox(
        width: 80,
        child: TextField(
          controller: ctrl,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
          ],
          textAlign: TextAlign.center,
          style: TextStyle(color: onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: '0',
            filled: true,
            fillColor: fillColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(_validateSplitAmounts),
        ),
      );
    }

    final rows = <Widget>[];

    for (final p in _participants) {
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  p.includedInSplit = !p.includedInSplit;
                  if (!p.includedInSplit) p.owedController.text = '0';
                  _updateEqualSplits();
                  _validateSplitAmounts();
                });
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: p.includedInSplit ? _accent : Colors.grey,
                child: Text(
                  p.name[0].toUpperCase(),
                  style: TextStyle(
                    color: p.includedInSplit ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(p.name,
                  style: TextStyle(
                      color: p.includedInSplit ? onSurface : Colors.grey,
                      fontSize: 14)),
            ),
            const Text('PKR ',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            amountField(p.owedController, enabled: _isCustomSplit),
          ],
        ),
      ));
    }

    for (var i = 0; i < _guests.length; i++) {
      final g = _guests[i];
      final label = g.nameCtrl.text.trim().isEmpty
          ? 'Guest ${i + 1}'
          : g.nameCtrl.text.trim();
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.amber,
              child: Text(
                label[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('$label (guest)',
                  style: TextStyle(color: onSurface, fontSize: 14)),
            ),
            const Text('PKR ',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            amountField(g.amountCtrl, enabled: _isCustomSplit),
          ],
        ),
      ));
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i != rows.length - 1)
                  const Divider(
                      color: Colors.white12,
                      height: 1,
                      indent: 16,
                      endIndent: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTotalCard(
          label: 'Assigned',
          assigned: _registeredOwed + _guestTotal,
        ),
        if (_splitErrorMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_splitErrorMessage,
              style: const TextStyle(color: _red, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildTotalCard({required String label, required double assigned}) {
    final diff = assigned - _totalAmount;
    final isMatched = diff.abs() < 0.01 && _totalAmount > 0;
    final isOver = diff > 0.01;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label: PKR ${assigned.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          if (isMatched)
            const Row(
              children: [
                Icon(Icons.check_circle, color: _accent, size: 16),
                SizedBox(width: 4),
                Text('Matched!',
                    style: TextStyle(
                        color: _accent, fontWeight: FontWeight.bold)),
              ],
            )
          else if (_totalAmount > 0)
            Text(
              isOver
                  ? 'PKR ${diff.toStringAsFixed(0)} over'
                  : 'PKR ${diff.abs().toStringAsFixed(0)} left',
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
          borderRadius: BorderRadius.circular(12)),
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
                  const Text('Settlement Preview',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
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
                  ? const Text('Enter amounts to see who pays whom',
                      style: TextStyle(color: Colors.grey, fontSize: 12))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...settlements.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Text(s['fromName'] as String,
                                      style: TextStyle(
                                          color: onSurface, fontSize: 12)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward,
                                      color: Colors.grey, size: 14),
                                  const SizedBox(width: 8),
                                  Text(s['toName'] as String,
                                      style: TextStyle(
                                          color: onSurface, fontSize: 12)),
                                  const Spacer(),
                                  Text(
                                    'PKR ${(s['amount'] as double).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        color: _accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
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
              hint: 'Add a note (optional)', prefixIcon: Icons.notes_outlined),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 2.5),
              )
            : const Text('Add Expense',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
      ),
    );
  }
}
