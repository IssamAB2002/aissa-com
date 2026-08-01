import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/zr_settings.dart';
import '../providers/shipping_reference_provider.dart';

class ZrSettingsScreen extends ConsumerStatefulWidget {
  const ZrSettingsScreen({super.key});

  @override
  ConsumerState<ZrSettingsScreen> createState() => _ZrSettingsScreenState();
}

class _ZrSettingsScreenState extends ConsumerState<ZrSettingsScreen> {
  final _secretKeyCtrl = TextEditingController();
  final _tenantIdCtrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _syncingTerritories = false;
  bool _syncingHubs = false;

  @override
  void dispose() {
    _secretKeyCtrl.dispose();
    _tenantIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await ref.read(shippingReferenceServiceProvider).saveZrSettings(
            ZrSettings(
              secretKey: _secretKeyCtrl.text.trim(),
              tenantId: _tenantIdCtrl.text.trim(),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ZR Express settings saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncTerritories() async {
    final secretKey = _secretKeyCtrl.text.trim();
    final tenantId = _tenantIdCtrl.text.trim();
    if (secretKey.isEmpty || tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter and save credentials first.')),
      );
      return;
    }
    setState(() => _syncingTerritories = true);
    try {
      final result = await ref
          .read(shippingReferenceServiceProvider)
          .syncTerritoriesFromZr(secretKey, tenantId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${result.wilayas} wilayas, ${result.baladias} baladias synced.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingTerritories = false);
    }
  }

  Future<void> _syncHubs() async {
    final secretKey = _secretKeyCtrl.text.trim();
    final tenantId = _tenantIdCtrl.text.trim();
    if (secretKey.isEmpty || tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter and save credentials first.')),
      );
      return;
    }
    setState(() => _syncingHubs = true);
    try {
      final count = await ref
          .read(shippingReferenceServiceProvider)
          .syncHubsFromZr(secretKey, tenantId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count hubs synced.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingHubs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ZrSettings>>(zrSettingsStreamProvider, (_, next) {
      next.whenData((s) {
        if (!_loaded) {
          _loaded = true;
          _secretKeyCtrl.text = s.secretKey;
          _tenantIdCtrl.text = s.tenantId;
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('ZR Express Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Credentials', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Stored in Firestore and used to call the ZR Express API directly '
            'from this app.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _secretKeyCtrl,
            decoration: const InputDecoration(labelText: 'Secret Key'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tenantIdCtrl,
            decoration: const InputDecoration(labelText: 'Tenant ID'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveSettings,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save Credentials'),
            ),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          Text('Sync Reference Data',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Pulls wilayas, baladias & hubs from ZR Express into this app.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _syncingTerritories ? null : _syncTerritories,
            icon: _syncingTerritories
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.map_outlined),
            label: const Text('Sync Wilayas & Baladias'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _syncingHubs ? null : _syncHubs,
            icon: _syncingHubs
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.store_outlined),
            label: const Text('Sync Hubs'),
          ),
        ],
      ),
    );
  }
}
