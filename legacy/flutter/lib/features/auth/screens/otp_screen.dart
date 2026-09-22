import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/dolpin_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _error;

  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == 6) {
      _verify();
    }
  }

  Future<void> _verify() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    final verifyResult = await authRepo.verifyOtp(widget.phone, _otp);

    if (!mounted) return;

    await verifyResult.when(
      success: (response) async {
        if (response.session != null) {
          final profileResult = await authRepo.getProfile(response.user!.id);
          if (!mounted) return;
          profileResult.when(
            success: (profile) {
              if (profile == null) {
                context.goNamed('signup');
              } else {
                context.go('/');
              }
            },
            failure: (_) => context.goNamed('signup'),
          );
        }
      },
      failure: (_) {
        setState(() => _error = AppLocalizations.of(context)!.invalidCode);
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      },
    );

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.verify)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.enterVerificationCode,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l.sentTo(widget.phone),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 48,
                  height: 56,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => _onChanged(i, v),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            DolpinButton(
              label: l.verify,
              isLoading: _isLoading,
              onPressed: _otp.length == 6 ? _verify : null,
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () async {
                  await ref
                      .read(authRepositoryProvider)
                      .signInWithOtp(widget.phone);
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l.codeResent)));
                  }
                },
                child: Text(l.resendCode),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
