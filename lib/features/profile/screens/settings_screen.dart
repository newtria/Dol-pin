import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/dialogs/confirm_dialog.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _currencyLabel(AppLocalizations l, String code) => switch (code) {
    'KRW' => l.currencyKRW,
    'IDR' => l.currencyIDR,
    'JPY' => l.currencyJPY,
    'USD' => l.currencyUSD,
    _ => code,
  };

  String _localeLabel(AppLocalizations l, String code) => switch (code) {
    'ko' => l.langKorean,
    'en' => l.langEnglish,
    'id' => l.langIndonesian,
    'ja' => l.langJapanese,
    _ => code,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final user = ref.watch(currentUserProvider).value;
    final userCurrency = user?.currency ?? 'KRW';
    final userLocale = user?.locale ?? 'en';
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          _SettingsSection(
            title: l.preferences,
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l.language),
                subtitle: Text(_localeLabel(l, userLocale)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguagePicker(context, ref, userLocale),
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: Text(l.currency),
                subtitle: Text(_currencyLabel(l, userCurrency)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCurrencyPicker(context, ref, userCurrency),
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(l.region),
                subtitle: Text(l.countryKorea),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.comingSoon)),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: l.notifications,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: Text(l.pushNotifications),
                value: true,
                onChanged: (v) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.comingSoon)),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.chat_outlined),
                title: Text(l.chatNotifications),
                value: true,
                onChanged: (v) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.comingSoon)),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: l.account,
            children: [
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(l.exportMyData),
                subtitle: Text(l.downloadAsJson),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.comingSoon)),
                ),
              ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: AppColors.error),
                title: Text(l.deleteAccount,
                    style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  final confirmed = await ConfirmDialog.show(
                    context,
                    title: l.deleteAccount,
                    message: l.deleteAccountMessage,
                    confirmLabel: l.delete,
                    isDestructive: true,
                  );
                  if (confirmed && context.mounted) {
                    final userId = ref.read(currentUserIdProvider);
                    if (userId != null) {
                      final result = await ref
                          .read(authRepositoryProvider)
                          .softDelete(userId);
                      if (context.mounted) {
                        result.when(
                          success: (_) {},
                          failure: (f) =>
                              ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${l.deleteAccountFailed}: ${f.message}')),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              l.appVersion('0.1.0'),
              style: TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref, String currentLocale) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (code, name) in [
              ('ko', l.langKorean),
              ('en', l.langEnglish),
              ('id', l.langIndonesian),
              ('ja', l.langJapanese),
            ])
              ListTile(
                title: Text(name),
                trailing: code == currentLocale
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  final userId = ref.read(currentUserIdProvider);
                  if (userId != null) {
                    ref.read(authRepositoryProvider).updateProfile(userId, {'locale': code});
                    ref.invalidate(currentUserProvider);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref, String currentCurrency) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (code, name) in [
              ('KRW', l.currencyKRW),
              ('IDR', l.currencyIDR),
              ('JPY', l.currencyJPY),
              ('USD', l.currencyUSD),
            ])
              ListTile(
                title: Text(name),
                trailing: code == currentCurrency
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  final userId = ref.read(currentUserIdProvider);
                  if (userId != null) {
                    ref.read(authRepositoryProvider).updateProfile(userId, {'currency': code});
                    ref.invalidate(currentUserProvider);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...children,
        const Divider(color: AppColors.divider),
      ],
    );
  }
}
