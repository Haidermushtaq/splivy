import 'package:flutter/material.dart';

// ── Shared pulse animation ────────────────────────────────────────────────────

class _SkeletonPulse extends StatefulWidget {
  final Widget Function(BuildContext context, double opacity) builder;
  const _SkeletonPulse({required this.builder});

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) => widget.builder(context, _opacity.value),
    );
  }
}

Widget _block(double width, double height, {double radius = 8}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.grey.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

// ── Balance card skeleton ─────────────────────────────────────────────────────

/// Shown while the real-time balance stream hasn't emitted its first value.
class BalanceCardSkeleton extends StatelessWidget {
  const BalanceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      builder: (_, opacity) => Opacity(
        opacity: opacity,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _block(90, 14),
              const SizedBox(height: 12),
              _block(170, 38),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(children: [
                      _block(64, 12),
                      const SizedBox(height: 6),
                      _block(100, 18),
                    ]),
                  ),
                  Container(width: 1, height: 36, color: Colors.white12),
                  Expanded(
                    child: Column(children: [
                      _block(64, 12),
                      const SizedBox(height: 6),
                      _block(100, 18),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Group card skeleton ───────────────────────────────────────────────────────

/// Shown for each group row while the groups list is loading.
class GroupCardSkeleton extends StatelessWidget {
  const GroupCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      builder: (_, opacity) => Opacity(
        opacity: opacity,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _block(48, 48, radius: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _block(120, 14),
                      const SizedBox(height: 6),
                      _block(80, 11),
                      const SizedBox(height: 4),
                      _block(100, 11),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _block(60, 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-page group list skeleton — used as the loading state in GroupsScreen.
class GroupListSkeleton extends StatelessWidget {
  final int count;
  const GroupListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, index) => const GroupCardSkeleton(),
    );
  }
}

// ── Friend card skeleton ──────────────────────────────────────────────────────

/// Shown for each friend row while the friends list is loading.
class FriendCardSkeleton extends StatelessWidget {
  const FriendCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      builder: (_, opacity) => Opacity(
        opacity: opacity,
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _block(48, 48, radius: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _block(130, 14),
                      const SizedBox(height: 6),
                      _block(80, 11),
                    ],
                  ),
                ),
                _block(64, 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sliver version for use inside CustomScrollView in FriendsScreen.
class FriendListSkeleton extends StatelessWidget {
  final int count;
  const FriendListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, index) => const FriendCardSkeleton(),
          childCount: count,
        ),
      ),
    );
  }
}

// ── Expense card skeleton ─────────────────────────────────────────────────────

/// Shown for each expense row while the expense list is loading.
class ExpenseCardSkeleton extends StatelessWidget {
  const ExpenseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      builder: (_, opacity) => Opacity(
        opacity: opacity,
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _block(44, 44, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _block(140, 14),
                      const SizedBox(height: 6),
                      _block(80, 11),
                      const SizedBox(height: 4),
                      _block(100, 11),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _block(70, 13),
                    const SizedBox(height: 6),
                    _block(50, 10),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
