import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/dolpin_button.dart';
import '../widgets/social_login_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    final phoneRegex = RegExp(r'^\+[1-9]\d{6,14}$');
    if (!phoneRegex.hasMatch(phone)) {
      setState(() => _error = AppLocalizations.of(context)!.invalidPhoneFormat);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ref.read(authRepositoryProvider).signInWithOtp(phone);
    if (!mounted) return;

    result.when(
      success: (_) => context.pushNamed('otp', queryParameters: {'phone': phone}),
      failure: (f) => setState(() => _error = f.message),
    );
    setState(() => _isLoading = false);
  }

  Future<void> _signInWithApple() async {
    final result = await ref.read(authRepositoryProvider).signInWithApple();
    if (!mounted) return;
    result.when(
      success: (_) {},
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.appleSignInFailed}: ${f.message}')),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    final result = await ref.read(authRepositoryProvider).signInWithGoogle();
    if (!mounted) return;
    result.when(
      success: (_) {},
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.googleSignInFailed}: ${f.message}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              Text(
                l.appTitle,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.primary,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                l.tagline,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
              ),
              const Spacer(flex: 3),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: l.phoneHint,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              DolpinButton(
                label: l.continueWithPhone,
                isLoading: _isLoading,
                onPressed: _sendOtp,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l.or,
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.divider)),
                ],
              ),
              const SizedBox(height: 24),
              SocialLoginButton(
                provider: SocialProvider.apple,
                onPressed: _signInWithApple,
              ),
              const SizedBox(height: 12),
              SocialLoginButton(
                provider: SocialProvider.google,
                onPressed: _signInWithGoogle,
              ),
              const Spacer(),
              Center(
                child: Text(
                  l.termsNotice,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
