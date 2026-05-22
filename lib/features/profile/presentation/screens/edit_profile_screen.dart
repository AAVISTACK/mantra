import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/mantra_button.dart';
import '../../../profile/providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _State();
}

class _State extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: ref.read(profileNotifierProvider).value?.displayName ?? '');
  }
  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.instance.post(ApiConstants.updateProfile, data: {'display_name': _nameCtrl.text.trim()});
      await ref.read(profileNotifierProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: \$e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Edit Profile'), backgroundColor: Colors.transparent),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(AppSpacing.screenPadding), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Display Name', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(controller: _nameCtrl, decoration: InputDecoration(
          filled: true, fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLG), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLG), borderSide: BorderSide(color: AppColors.border)),
          hintText: 'Your first name')),
        const SizedBox(height: 8),
        Text('Only your first name will be shown to others.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const Spacer(),
        _saving ? const Center(child: CircularProgressIndicator()) : MantraButton(label: 'Save Changes', onPressed: _save),
      ],
    ))),
  );
}
