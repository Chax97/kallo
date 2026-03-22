import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/providers/sip_provider.dart';
import 'dialler/screens/dialler_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://iqzewdhqmpqligwochua.supabase.co',
    anonKey: 'sb_publishable_-3a2oDGKp1K-y7kDOS-Uaw_N8Gm1Lgg',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(
    const ProviderScope(
      child: KalloApp(),
    ),
  );
}

final supabase = Supabase.instance.client;

class KalloApp extends ConsumerWidget {
  const KalloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(telnyxAudioProvider);

    return MaterialApp(
      title: 'Kallo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: supabase.auth.currentSession != null
          ? const DiallerDashboard()
          : const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DiallerDashboard()),
        );
      }
    });
  }

  /// Starts a localhost HTTP server, opens the browser for OAuth,
  /// and waits for Supabase to redirect back with the PKCE auth code.
  Future<void> _signInWithOAuthViaLocalhost(OAuthProvider provider) async {
    setState(() => _loading = true);
    HttpServer? server;
    try {
      // Start a temporary HTTP server on a random available port
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUrl = 'http://localhost:$port/auth-callback';

      // signInWithOAuth generates PKCE code verifier/challenge internally,
      // stores the verifier, and opens the browser via url_launcher.
      unawaited(supabase.auth.signInWithOAuth(
        provider,
        redirectTo: redirectUrl,
      ));

      // Wait for the callback request with the PKCE auth code
      await for (final request in server) {
        final uri = request.requestedUri;
        if (uri.path == '/auth-callback') {
          final code = uri.queryParameters['code'];

          // Respond to the browser
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(
              '<html><head><script>window.close();</script></head>'
              '<body style="background:#0F0F1A;color:white;font-family:sans-serif;'
              'display:flex;justify-content:center;align-items:center;height:100vh">'
              '<div style="text-align:center"><p>You can close this tab.</p></div></body></html>',
            );
          await request.response.close();
          await server?.close();
          server = null;

          // Exchange the PKCE code for a session (uses stored code verifier)
          if (code != null) {
            await supabase.auth.exchangeCodeForSession(code);
          }
          break;
        } else {
          // Ignore unrelated requests (favicon etc.)
          request.response
            ..statusCode = 404
            ..write('Not found');
          await request.response.close();
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      await server?.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'kallo',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6C63FF),
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI-powered communications',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white54,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 60),
            if (_loading)
              const CircularProgressIndicator(color: Color(0xFF6C63FF))
            else ...[
              ElevatedButton.icon(
                onPressed: () => _signInWithOAuthViaLocalhost(OAuthProvider.google),
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _signInWithOAuthViaLocalhost(OAuthProvider.azure),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Continue with Microsoft'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
