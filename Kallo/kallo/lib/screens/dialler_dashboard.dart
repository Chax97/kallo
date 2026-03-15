import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../providers/sip_provider.dart' show vertoProvider;
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
    ref.watch(telnyxProvider);
    ref.watch(vertoProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ── Invisible audio renderer (required for WebRTC audio on Windows)
          Positioned(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            child: Consumer(
              builder: (context, ref, _) {
                ref.watch(vertoProvider);
                final notifier = ref.read(vertoProvider.notifier);
                if (!notifier.hasRemoteRenderer) return const SizedBox.shrink();
                return RTCVideoView(
                  notifier.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                );
              },
            ),
          ),
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
          const FloatingDialer(),
          const ActiveCallOverlay(),
        ],
      ),
    );
  }
}
