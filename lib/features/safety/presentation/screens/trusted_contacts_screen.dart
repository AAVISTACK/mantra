import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/mantra_button.dart';

class _Contact { final String name, phone; const _Contact(this.name, this.phone); }

final _contactsProvider = FutureProvider<List<_Contact>>((ref) async {
  final res = await ApiClient.instance.get(ApiConstants.trustedContacts);
  return ((res.data['data'] as List?) ?? []).map((c) => _Contact(c['name'] as String, c['phone'] as String)).toList();
});

class TrustedContactsScreen extends ConsumerWidget {
  const TrustedContactsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(_contactsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Trusted Contacts'), backgroundColor: Colors.transparent),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: \$e')),
        data: (contacts) => ListView(padding: const EdgeInsets.all(AppSpacing.screenPadding), children: [
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.trust.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
              border: Border.all(color: AppColors.trust.withOpacity(0.2))),
            child: Text('🛡️ These people receive an emergency alert if you activate SOS. Add up to 3 contacts.',
                style: TextStyle(color: AppColors.trust, fontSize: 13, height: 1.5))),
          const SizedBox(height: 24),
          ...contacts.map((c) => ListTile(contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: AppColors.primaryLight.withOpacity(0.3),
              child: Text(c.name[0].toUpperCase(), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(c.phone, style: TextStyle(color: AppColors.textMuted)))),
          const SizedBox(height: 16),
          if (contacts.length < 3)
            MantraButton(label: 'Add Trusted Contact', icon: Icons.person_add_rounded,
              onPressed: () => _showAddDialog(context, ref)),
        ]),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController(); final phoneCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Add Contact'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Full name')),
        const SizedBox(height: 12),
        TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: 'Phone number')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () async {
          try {
            await ApiClient.instance.post(ApiConstants.trustedContacts,
              data: {'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim()});
            if (context.mounted) { Navigator.pop(context); ref.invalidate(_contactsProvider); }
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
          }
        }, child: const Text('Add')),
      ]));
  }
}
