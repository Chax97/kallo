import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/telnyx_provider.dart';
import '../widgets/dialler/active_call_overlay.dart';
import '../widgets/dialler/call_list_panel.dart';
import '../widgets/dialler/floating_dialer.dart';
import '../widgets/dialler/main_content_area.dart';
import '../widgets/dialler/sidebar.dart';
import '../widgets/dialler/top_bar.dart';

class DiallerDashboard extends ConsumerWidget {
  const DiallerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialise the Telnyx SIP connection as soon as the dashboard loads.
    ref.watch(telnyxProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ── Main layout ──────────────────────────────────────────────────
          Row(
            children: [
              const DiallerSidebar(),
              Expanded(
                child: Column(
                  children: [
                    const DiallerTopBar(),
                    Expanded(
                      child: Row(
                        children: const [
                          Expanded(child: MainContentArea()),
                          CallListPanel(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── Floating draggable dialer ─────────────────────────────────────
          const FloatingDialer(),
          // ── Active call overlay ───────────────────────────────────────────
          const ActiveCallOverlay(),
        ],
      ),
    );
  }
}
