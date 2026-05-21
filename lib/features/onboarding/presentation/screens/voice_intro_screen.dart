import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/mantra_button.dart';

enum VoiceRecordState { idle, recording, recorded, playing }

class VoiceIntroScreen extends ConsumerStatefulWidget {
  const VoiceIntroScreen({super.key});

  @override
  ConsumerState<VoiceIntroScreen> createState() => _VoiceIntroScreenState();
}

class _VoiceIntroScreenState extends ConsumerState<VoiceIntroScreen>
    with SingleTickerProviderStateMixin {
  final _audioRecorder = AudioRecorder();
  final _player = AudioPlayer();
  late RecorderController _recorderController;
  late PlayerController _playerController;

  VoiceRecordState _state = VoiceRecordState.idle;
  String? _recordedPath;
  int _recordingSeconds = 0;
  int _maxSeconds = 45;
  int _minSeconds = 15;

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
    _playerController = PlayerController();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _player.dispose();
    _recorderController.dispose();
    _playerController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final micPerm = await Permission.microphone.request();
    if (!micPerm.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is needed')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final dir = await getApplicationDocumentsDirectory();
    _recordedPath = '${dir.path}/voice_intro_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorderController.record(path: _recordedPath!);
    setState(() {
      _state = VoiceRecordState.recording;
      _recordingSeconds = 0;
    });

    // Count up
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_state != VoiceRecordState.recording) return false;
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= _maxSeconds) {
        _stopRecording();
        return false;
      }
      return true;
    });
  }

  Future<void> _stopRecording() async {
    if (_recordingSeconds < _minSeconds) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please record at least $_minSeconds seconds'),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    await _recorderController.stop();
    await _playerController.preparePlayer(
      path: _recordedPath!,
      shouldExtractWaveform: true,
    );
    setState(() => _state = VoiceRecordState.recorded);
  }

  Future<void> _playPreview() async {
    if (_playerController.playerState == PlayerState.playing) {
      await _playerController.pausePlayer();
      setState(() => _state = VoiceRecordState.recorded);
    } else {
      await _playerController.startPlayer();
      setState(() => _state = VoiceRecordState.playing);
      _playerController.onCompletion.listen((_) {
        if (mounted) setState(() => _state = VoiceRecordState.recorded);
      });
    }
  }

  Future<void> _deleteRecording() async {
    await _playerController.stopPlayer();
    if (_recordedPath != null) {
      final file = File(_recordedPath!);
      if (await file.exists()) await file.delete();
    }
    setState(() {
      _state = VoiceRecordState.idle;
      _recordedPath = null;
      _recordingSeconds = 0;
    });
  }

  String get _timerText {
    final remaining = _maxSeconds - _recordingSeconds;
    return '${remaining}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => context.push('/onboarding/photos'),
            child: Text(
              'Skip',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepIndicator(current: 4, total: 6),
              const SizedBox(height: 32),

              Text(
                'Your voice,\nyour first impression.',
                style: AppTextStyles.heroDisplay,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 10),

              Text(
                'Answer this prompt in 15–45 seconds:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ).animate(delay: 100.ms).fadeIn(),

              const SizedBox(height: 16),

              // Prompt card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  border: Border.all(
                    color: AppColors.primaryLight.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '🎙️ Tell us three things — one fact about you, one thing you\'re curious about, and one unpopular opinion.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ).animate(delay: 150.ms).fadeIn(),

              const Spacer(),

              // Waveform / recording visual
              if (_state == VoiceRecordState.recording)
                Center(
                  child: AudioWaveforms(
                    size: Size(MediaQuery.of(context).size.width - 40, 80),
                    recorderController: _recorderController,
                    waveStyle: WaveStyle(
                      waveColor: AppColors.primary,
                      showDurationLabel: false,
                      spacing: 8.0,
                      showBottom: true,
                      extendWaveform: true,
                      showMiddleLine: false,
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms),

              if (_state == VoiceRecordState.recorded ||
                  _state == VoiceRecordState.playing)
                Center(
                  child: AudioFileWaveforms(
                    size: Size(MediaQuery.of(context).size.width - 40, 80),
                    playerController: _playerController,
                    waveformType: WaveformType.fitWidth,
                    playerWaveStyle: PlayerWaveStyle(
                      fixedWaveColor: AppColors.border,
                      liveWaveColor: AppColors.primary,
                      spacing: 8,
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms),

              if (_state == VoiceRecordState.idle)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.mic_none_rounded,
                        size: 64,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap the mic to start recording',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 32),

              // Timer display while recording
              if (_state == VoiceRecordState.recording)
                Center(
                  child: Text(
                    _timerText,
                    style: TextStyle(
                      color: _recordingSeconds > 35
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Action buttons
              if (_state == VoiceRecordState.idle)
                _RecordButton(onTap: _startRecording),

              if (_state == VoiceRecordState.recording)
                _StopButton(onTap: _stopRecording),

              if (_state == VoiceRecordState.recorded ||
                  _state == VoiceRecordState.playing)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MantraButton(
                            label: _state == VoiceRecordState.playing
                                ? 'Pause'
                                : 'Preview',
                            onPressed: _playPreview,
                            variant: MantraButtonVariant.outline,
                            icon: _state == VoiceRecordState.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _deleteRecording,
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: AppColors.error,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.error.withOpacity(0.1),
                            padding: const EdgeInsets.all(14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    MantraButton(
                      label: 'Sounds good! Continue →',
                      onPressed: () => context.push('/onboarding/photos'),
                    ),
                  ],
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RecordButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.mic_rounded,
            color: Colors.white,
            size: 36,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1.0, end: 1.04, duration: 1200.ms, curve: Curves.easeInOut),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.stop_rounded,
            color: Colors.white,
            size: 36,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1.0, end: 1.06, duration: 700.ms, curve: Curves.easeInOut),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            height: 4,
            decoration: BoxDecoration(
              color: i < current ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
