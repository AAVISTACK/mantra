import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/spark_model.dart';
import '../data/repositories/sparks_repository.dart';

final sparksRepositoryProvider = Provider<SparksRepository>((_) => SparksRepositoryImpl());

final sparksProvider = AsyncNotifierProvider<SparksNotifier, List<SparkModel>>(SparksNotifier.new);

class SparksNotifier extends AsyncNotifier<List<SparkModel>> {
  @override
  Future<List<SparkModel>> build() async =>
      ref.read(sparksRepositoryProvider).getDailySparks();

  Future<void> connect(String userId, {BuildContext? context}) async {
    state = AsyncData((state.value ?? []).where((s) => s.userId != userId).toList());
    try {
      final isMutual = await ref.read(sparksRepositoryProvider).connectSpark(userId);
      if (isMutual && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("It's a match! 💫 You can now chat."),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
      }
    }
  }

  Future<void> pass(String userId) async {
    state = AsyncData((state.value ?? []).where((s) => s.userId != userId).toList());
    try { await ref.read(sparksRepositoryProvider).passSpark(userId); } catch (_) {}
  }

  Future<void> save(String userId) async {
    state = AsyncData((state.value ?? []).where((s) => s.userId != userId).toList());
  }
}
