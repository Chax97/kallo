import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  static const Color kBrand   = Color(0xFF0F0F0F);
  static const Color kAccent  = Color(0xFF6C63FF);
  static const Color kSurface = Color(0xFFF7F7F8);
  static const Color kBorder  = Color(0xFFE5E7EB);
  static const Color kSubtext = Color(0xFF6B7280);
  static const Color kLabel   = Color(0xFF111827);
  static const Color kError   = Color(0xFFDC2626);
  static const Color kErrorBg = Color(0xFFFEF2F2);

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.session != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));

        final user = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('id', response.session!.user.id)
            .maybeSingle();

        final role = user?['role'] as String?;
        if (user == null || (role != 'admin' && role != 'super_admin')) {
          await Supabase.instance.client.auth.signOut();
          setState(() { _error = 'Access denied. Admin accounts only.'; });
          _shakeController.forward(from: 0);
          return;
        }

        if (mounted) context.go('/dashboard');
      }
    } on AuthException catch (e) {
      setState(() { _error = e.message; });
      _shakeController.forward(from: 0);
    } catch (e) {
      setState(() { _error = 'An unexpected error occurred.'; });
      _shakeController.forward(from: 0);
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 220,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            kAccent.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildCard(),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Kallo Admin · Secure access only',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 12,
                  color: kSubtext.withValues(alpha: 0.6),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final dx = _error != null
            ? 6 * (0.5 - (_shakeAnimation.value % 1.0)).abs() * 2
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 40,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gradient accent bar
              Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kAccent, Color(0xFF8B5CF6)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    if (_error != null) ...[
                      _buildErrorBanner(),
                      const SizedBox(height: 20),
                    ],
                    _buildEmailField(),
                    const SizedBox(height: 16),
                    _buildPasswordField(),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 13,
                            color: kAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSignInButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kBrand,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 20),
        const Text(
          'Sign in to Kallo',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: kLabel,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kErrorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kError.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: kError, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 13,
                color: kError,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Email', style: TextStyle(
          fontFamily: 'DM Sans', fontSize: 13, fontWeight: FontWeight.w600,
          color: kLabel, letterSpacing: 0.1,
        )),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _signIn(),
          style: const TextStyle(fontFamily: 'DM Sans', fontSize: 14, color: kLabel),
          decoration: InputDecoration(
            hintText: 'you@company.com',
            hintStyle: TextStyle(fontFamily: 'DM Sans', color: kSubtext.withValues(alpha: 0.5), fontSize: 14),
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 18, color: kSubtext.withValues(alpha: 0.7)),
            filled: true,
            fillColor: kSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kAccent, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Password', style: TextStyle(
          fontFamily: 'DM Sans', fontSize: 13, fontWeight: FontWeight.w600,
          color: kLabel, letterSpacing: 0.1,
        )),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          onSubmitted: (_) => _signIn(),
          style: const TextStyle(fontFamily: 'DM Sans', fontSize: 14, color: kLabel),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(fontFamily: 'DM Sans', color: kSubtext.withValues(alpha: 0.5), fontSize: 14),
            prefixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: kSubtext.withValues(alpha: 0.7)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: kSubtext.withValues(alpha: 0.7),
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: kSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kAccent, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _loading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: kBrand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kBrand.withValues(alpha: 0.7),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Sign in', style: TextStyle(
                fontFamily: 'DM Sans', fontSize: 15,
                fontWeight: FontWeight.w600, letterSpacing: 0.1,
              )),
      ),
    );
  }
}
