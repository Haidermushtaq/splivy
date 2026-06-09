import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/expense_model.dart';
import '../../providers/expenses_provider.dart';

const _accent = Color(0xFF00D4AA);
const _danger = Color(0xFFFF6B6B);
const _amber = Color(0xFFFFB020);

/// Full record of every settled debt: who paid whom, for which expense, how it
/// was settled (payment method or auto-net offset), and any payment proof.
/// Records are grouped by counterpart so the per-person breakdown is visible.
class SettlementHistoryScreen extends ConsumerWidget {
  const SettlementHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settlementHistoryProvider);
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Settlement History')),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _accent)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          ),
        ),
        data: (records) {
          if (records.isEmpty) return _empty(context);
          final groups = _groupByCounterpart(records);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(settlementHistoryProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: groups.length,
              itemBuilder: (context, i) => _CounterpartCard(group: groups[i]),
            ),
          );
        },
      ),
    );
  }

  List<_CounterpartGroup> _groupByCounterpart(List<SettlementRecord> records) {
    final map = <String, List<SettlementRecord>>{};
    for (final r in records) {
      map.putIfAbsent(r.counterpartName, () => []).add(r);
    }
    final groups = map.entries
        .map((e) => _CounterpartGroup(name: e.key, records: e.value))
        .toList();
    // Most recently active counterpart first.
    groups.sort((a, b) => b.lastSettledAt.compareTo(a.lastSettledAt));
    return groups;
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_outlined, color: Colors.grey, size: 56),
          const SizedBox(height: 14),
          Text(
            'No settlements yet',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Settled and offset debts will appear here',
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CounterpartGroup {
  final String name;
  final List<SettlementRecord> records;

  _CounterpartGroup({required this.name, required this.records});

  DateTime get lastSettledAt =>
      records.map((r) => r.settledAt).reduce((a, b) => a.isAfter(b) ? a : b);

  double get youPaidTotal =>
      records.where((r) => r.youPaid).fold(0, (s, r) => s + r.amount);

  double get youReceivedTotal =>
      records.where((r) => !r.youPaid).fold(0, (s, r) => s + r.amount);
}

class _CounterpartCard extends StatefulWidget {
  final _CounterpartGroup group;
  const _CounterpartCard({required this.group});

  @override
  State<_CounterpartCard> createState() => _CounterpartCardState();
}

class _CounterpartCardState extends State<_CounterpartCard> {
  bool _expanded = true;

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final g = widget.group;
    final records = [...g.records]
      ..sort((a, b) => b.settledAt.compareTo(a.settledAt));

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _accent.withValues(alpha: 0.15),
                    child: Text(
                      g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: _accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.name,
                          style: TextStyle(
                              color: onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${records.length} settlement${records.length == 1 ? '' : 's'}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (g.youPaidTotal > 0.01)
                        Text(
                          'You paid PKR ${g.youPaidTotal.toStringAsFixed(0)}',
                          style: const TextStyle(color: _danger, fontSize: 12),
                        ),
                      if (g.youReceivedTotal > 0.01)
                        Text(
                          'Received PKR ${g.youReceivedTotal.toStringAsFixed(0)}',
                          style: const TextStyle(color: _accent, fontSize: 12),
                        ),
                    ],
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white12, height: 1),
            ...records.map((r) => _RecordRow(
                  record: r,
                  formattedDate: _formatDate(r.settledAt),
                )),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final SettlementRecord record;
  final String formattedDate;

  const _RecordRow({required this.record, required this.formattedDate});

  String get _methodLabel {
    if (record.isOffset) return 'Auto-offset';
    final m = record.paymentMethod;
    switch (m) {
      case 'cash':
        return 'Cash';
      case 'easypaisa':
        return 'Easypaisa';
      case 'jazzcash':
        return 'JazzCash';
      case 'bank':
      case 'bank_transfer':
        return 'Bank transfer';
      case null:
      case '':
        return record.isCash ? 'Cash' : 'Marked settled';
      default:
        return m[0].toUpperCase() + m.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final directionColor = record.youPaid ? _danger : _accent;
    final directionText = record.isOffset
        ? (record.youPaid
            ? 'Your debt of PKR ${record.amount.toStringAsFixed(0)} was offset'
            : 'PKR ${record.amount.toStringAsFixed(0)} owed to you was offset')
        : (record.youPaid
            ? 'You paid ${record.counterpartName}'
            : '${record.counterpartName} paid you');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (record.isOffset ? _amber : directionColor)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  record.isOffset
                      ? Icons.swap_horiz
                      : (record.youPaid
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded),
                  color: record.isOffset ? _amber : directionColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.expenseTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      directionText,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.groupName} • $formattedDate',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PKR ${record.amount.toStringAsFixed(0)}',
                style: TextStyle(
                    color: record.isOffset ? _amber : directionColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 46, top: 6),
            child: Row(
              children: [
                _Chip(
                  icon: record.isOffset
                      ? Icons.swap_horiz
                      : Icons.account_balance_wallet_outlined,
                  label: _methodLabel,
                  color: record.isOffset ? _amber : _accent,
                ),
                const SizedBox(width: 8),
                if (record.paymentProofUrl != null &&
                    record.paymentProofUrl!.isNotEmpty)
                  GestureDetector(
                    onTap: () =>
                        _showProofImage(context, record.paymentProofUrl!),
                    child: const _Chip(
                      icon: Icons.image_outlined,
                      label: 'View proof',
                      color: Color(0xFF4F8CFF),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 18),
        ],
      ),
    );
  }

  void _showProofImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                        child: CircularProgressIndicator(color: _accent)),
                  );
                },
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(
                    child: Text('Could not load proof',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
