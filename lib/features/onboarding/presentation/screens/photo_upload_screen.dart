import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/mantra_button.dart';
import '../../providers/onboarding_provider.dart';

class PhotoUploadScreen extends ConsumerStatefulWidget {
  const PhotoUploadScreen({super.key});
  @override
  ConsumerState<PhotoUploadScreen> createState() => _State();
}

class _State extends ConsumerState<PhotoUploadScreen> {
  final _picker = ImagePicker();
  bool _uploading = false;

  Future<void> _pick() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      await ref.read(onboardingProvider.notifier).uploadPhoto(picked.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: \$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context, ) {
    final urls = ref.watch(onboardingProvider).photoUrls;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent,
        actions: [TextButton(onPressed: () => context.push('/onboarding/prompts'),
          child: Text('Skip', style: TextStyle(color: AppColors.textMuted)))]),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add your photos', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text("Photos are blurred until you reveal them. You're in control.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 32),
          _uploading
              ? const Center(child: CircularProgressIndicator())
              : GridView.count(
                  shrinkWrap: true, crossAxisCount: 3,
                  crossAxisSpacing: 10, mainAxisSpacing: 10,
                  children: List.generate(6, (i) {
                    final hasPhoto = i < urls.length;
                    return GestureDetector(
                      onTap: _pick,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: hasPhoto
                            ? ClipRRect(borderRadius: BorderRadius.circular(11),
                                child: Image.network(urls[i], fit: BoxFit.cover))
                            : Center(child: Icon(
                                i == 0 ? Icons.add_photo_alternate_outlined : Icons.add_rounded,
                                color: i == 0 ? AppColors.primary : AppColors.border,
                                size: i == 0 ? 28 : 24)),
                      ),
                    );
                  }),
                ),
          const Spacer(),
          MantraButton(
            label: urls.isEmpty ? 'Skip for now' : 'Continue',
            onPressed: () => context.push('/onboarding/prompts'),
            icon: Icons.arrow_forward_rounded,
          ),
        ]),
      )),
    );
  }
}
