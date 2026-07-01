import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../utils/google_auth_service.dart';
import '../../utils/other_auth_services.dart';

/// First-run account screen. Shown before onboarding when no account is
/// signed in yet (see main.dart's _AppEntry). Google Sign-In is fully wired
/// up (once OAuth credentials are configured in the Google Cloud Console —
/// see GoogleAuthService.setupInstructions). Microsoft and Apple buttons
/// are present and will show clear setup instructions if tapped before
/// their respective platform configuration is complete.
class LoginScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  final VoidCallback? onSkip;

  const LoginScreen({super.key, required this.onSignedIn, this.onSkip});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleAuthService _googleAuth = GoogleAuthService();
  final MicrosoftAuthService _microsoftAuth = MicrosoftAuthService();
  final AppleAuthService _appleAuth = AppleAuthService();

  bool _busy = false;
  String? _error;

  Future<void> _handleGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final success = await _googleAuth.signIn();
      if (success) {
        widget.onSignedIn();
        return;
      }
    } catch (e) {
      setState(() => _error =
          'Google Sign-In isn\'t configured for this build yet.\n\n'
          '${GoogleAuthService.setupInstructions}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleMicrosoft() async {
    setState(() => _error = MicrosoftAuthService.setupInstructions);
  }

  Future<void> _handleApple() async {
    setState(() => _error = AppleAuthService.setupInstructions);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kSpace24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7FB8F0), Color(0xFF5A8FE0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(height: kSpace24),
              Text(
                'Welcome',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: kSpace8),
              Text(
                'Sign in to sync your tasks and import from Google Sheets',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextMuted),
              ),
              const SizedBox(height: kSpace48),

              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: kSpace16),
                  padding: const EdgeInsets.all(kSpace16),
                  decoration: BoxDecoration(
                    color: kP1Red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kP1Red.withOpacity(0.3)),
                  ),
                  child: Text(_error!, style: const TextStyle(fontSize: 12, height: 1.4)),
                ),

              _ProviderButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                background: Colors.white,
                foreground: Colors.black87,
                border: isDark ? kDarkBorder : kLightBorder,
                busy: _busy,
                onTap: _handleGoogle,
              ),
              const SizedBox(height: kSpace12),
              _ProviderButton(
                label: 'Continue with Microsoft',
                icon: Icons.window_rounded,
                background: const Color(0xFF2F2F2F),
                foreground: Colors.white,
                onTap: _handleMicrosoft,
              ),
              const SizedBox(height: kSpace12),
              _ProviderButton(
                label: 'Continue with Apple',
                icon: Icons.apple,
                background: Colors.black,
                foreground: Colors.white,
                onTap: _handleApple,
              ),

              const Spacer(),
              if (widget.onSkip != null)
                TextButton(
                  onPressed: widget.onSkip,
                  child: const Text('Skip for now'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final bool busy;
  final VoidCallback onTap;

  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.border,
    this.busy = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: border != null ? BorderSide(color: border!) : BorderSide.none,
          ),
        ),
        child: busy
            ? SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: kSpace8),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
      ),
    );
  }
}
