import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectionStatusBar extends StatefulWidget {
  const ConnectionStatusBar({super.key});

  @override
  State<ConnectionStatusBar> createState() => _ConnectionStatusBarState();
}

class _ConnectionStatusBarState extends State<ConnectionStatusBar> {
  RealtimeSubscribeStatus? _status;
  bool _wasConnected = false;
  bool _showConnected = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _channel = Supabase.instance.client.channel('connection-monitor');
    _channel!.subscribe((status, error) {
      if (!mounted) return;
      final justConnected =
          status == RealtimeSubscribeStatus.subscribed && !_wasConnected;
      setState(() {
        _status = status;
        _wasConnected = status == RealtimeSubscribeStatus.subscribed;
        if (justConnected) _showConnected = true;
      });
      if (justConnected) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showConnected = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _status == RealtimeSubscribeStatus.subscribed;
    if (isConnected && !_showConnected) return const SizedBox.shrink();
    if (_status == null && !_showConnected) return const SizedBox.shrink();

    final Color color;
    final String message;

    if (_showConnected) {
      color = Colors.green.shade600;
      message = 'Connected';
    } else if (_status == RealtimeSubscribeStatus.channelError ||
        _status == RealtimeSubscribeStatus.timedOut ||
        _status == RealtimeSubscribeStatus.closed) {
      color = Colors.red.shade700;
      message = 'Offline - changes will sync when connected';
    } else {
      color = Colors.amber.shade700;
      message = 'Connecting...';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
