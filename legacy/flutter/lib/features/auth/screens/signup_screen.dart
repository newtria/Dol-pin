import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/dolpin_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nicknameController = TextEditingController();
  String _country = 'KR';
  final _favGroups = <String>[];
  final _groupController = TextEditingController();
  bool _isLoading = false;

  static List<(String, String)> _countries(AppLocalizations l) => [
    ('KR', l.countryKorea),
    ('ID', l.countryIndonesia),
    ('JP', l.countryJapan),
    ('US', l.countryUS),
  ];

  @override
  void dispose() {
    _nicknameController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  String get _currencyForCountry => LocaleUtils.currencyForCountry(_country);
  String get _localeForCountry => LocaleUtils.localeForCountry(_country);

  Future<void> _submit() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;

    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final result = await authRepo.createProfile({
      'id': user.id,
      'phone': user.phone ?? '',
      'nickname': nickname,
      'country': _country,
      'currency': _currencyForCountry,
      'locale': _localeForCountry,
      'fav_groups': _favGroups,
    });

    if (!mounted) return;
    result.when(
      success: (_) => context.go('/'),
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorPrefix(f.message)),
        ),
      ),
    );
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.createProfile)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.surfaceLight,
                    child: const Icon(
                      Icons.person,
                      size: 48,
                      color: AppColors.textHint,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(l.nickname, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(hintText: l.enterNickname),
            ),
            const SizedBox(height: 24),
            Text(l.country, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _countries(l).map((c) {
                final (code, name) = c;
                return ChoiceChip(
                  label: Text(name),
                  selected: _country == code,
                  onSelected: (_) => setState(() => _country = code),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              l.favoriteGroups,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _groupController,
              decoration: InputDecoration(hintText: l.typeAndEnter),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  setState(() {
                    _favGroups.add(value.trim());
                    _groupController.clear();
                  });
                }
              },
            ),
            if (_favGroups.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _favGroups.map((g) {
                  return Chip(
                    label: Text(g),
                    onDeleted: () {
                      setState(() => _favGroups.remove(g));
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 40),
            DolpinButton(
              label: l.getStarted,
              isLoading: _isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
