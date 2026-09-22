import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/datasources/bluetooth_service.dart';
import '../../../l10n/app_localizations.dart';

class BtVerifyButton extends ConsumerStatefulWidget {
  const BtVerifyButton({super.key, required this.onVerified});

  final void Function(LightstickInfo info) onVerified;

  @override
  ConsumerState<BtVerifyButton> createState() => _BtVerifyButtonState();
}

class _BtVerifyButtonState extends ConsumerState<BtVerifyButton> {
  bool _isScanning = false;

  Future<void> _scan() async {
    final l = AppLocalizations.of(context)!;

    // Bluetooth lightstick verification is not yet implemented.
    // Show a "coming soon" message instead of calling unimplemented methods.
    if (!BluetoothService.isImplemented) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.verifyLightstick} - ${l.comingSoon}')),
        );
      }
      return;
    }

    setState(() => _isScanning = true);

    final btService = ref.read(bluetoothServiceProvider);
    final available = await btService.isAvailable();

    if (!available && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.bluetoothNotAvailable)));
      setState(() => _isScanning = false);
      return;
    }

    final result = await btService.scanForLightsticks();
    if (!mounted) return;

    setState(() => _isScanning = false);

    result.when(
      success: (devices) {
        if (devices.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.noLightsticksFound)));
          return;
        }
        // Show picker if multiple devices
        if (devices.length == 1) {
          widget.onVerified(devices.first);
        } else {
          _showDevicePicker(devices);
        }
      },
      failure: (f) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(f.message)));
      },
    );
  }

  void _showDevicePicker(List<LightstickInfo> devices) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context)!.selectYourLightstick,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final device in devices)
              ListTile(
                leading: Icon(
                  Icons.bluetooth,
                  color: device.isAuthentic
                      ? AppColors.verified
                      : AppColors.textHint,
                ),
                title: Text(device.deviceName),
                subtitle: Text(device.artistGroup ?? device.manufacturerId),
                trailing: device.isAuthentic
                    ? const Icon(Icons.verified, color: AppColors.verified)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  widget.onVerified(device);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isScanning ? null : _scan,
      icon: _isScanning
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.bluetooth, size: 18),
      label: Text(
        _isScanning
            ? AppLocalizations.of(context)!.scanning
            : AppLocalizations.of(context)!.verifyLightstick,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.verified,
        side: const BorderSide(color: AppColors.verified),
      ),
    );
  }
}
