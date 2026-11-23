import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lafz/features/hub/hub_actions.dart';

/// Opened by the home-screen widget (lafz://lafz.app/hub/<action>).
/// Runs the action, shows the result for a moment, then returns to the
/// home screen so it feels like pressing a widget button.
class HubActionScreen extends ConsumerStatefulWidget {
  final String action;
  const HubActionScreen({super.key, required this.action});

  @override
  ConsumerState<HubActionScreen> createState() => _HubActionScreenState();
}

class _HubActionScreenState extends ConsumerState<HubActionScreen> {
  String _message = 'Working\u2026';
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final message = await HubActions.run(widget.action, ref, context);
    if (!mounted) return;
    setState(() {
      _message = message;
      _done = true;
    });

    await Future.delayed(const Duration(milliseconds: 1600));
    // Close the app so the user lands back on their home screen.
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_done)
                const CircularProgressIndicator()
              else
                Icon(Icons.check_circle_rounded,
                    size: 44, color: theme.colorScheme.primary),
              const SizedBox(height: 18),
              Text(
                _message,
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
