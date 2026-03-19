import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../layout/admin_shell.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/users/users_screen.dart';
import '../screens/phone_numbers/phone_numbers_screen.dart';
import '../screens/call_flows/call_flows_screen.dart';
import '../screens/hunt_groups/hunt_groups_screen.dart';
import '../screens/call_logs/call_logs_screen.dart';
import '../screens/ai_agents/ai_agents_screen.dart';
import '../screens/integrations/integrations_screen.dart';
import '../screens/templates/templates_screen.dart';
import '../auth/admin_login_screen.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/users',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UsersScreen(),
            ),
          ),
          GoRoute(
            path: '/phone-numbers',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PhoneNumbersScreen(),
            ),
          ),
          GoRoute(
            path: '/call-flows',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CallFlowsScreen(),
            ),
          ),
          GoRoute(
            path: '/hunt-groups',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HuntGroupsScreen(),
            ),
          ),
          GoRoute(
            path: '/call-logs',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CallLogsScreen(),
            ),
          ),
          GoRoute(
            path: '/ai-agents',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AiAgentsScreen(),
            ),
          ),
          GoRoute(
            path: '/integrations',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: IntegrationsScreen(),
            ),
          ),
          GoRoute(
            path: '/templates',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TemplatesScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
