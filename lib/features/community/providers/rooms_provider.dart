import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../data/models/room_model.dart';

final roomsProvider = AsyncNotifierProvider<RoomsNotifier, List<RoomModel>>(RoomsNotifier.new);

class RoomsNotifier extends AsyncNotifier<List<RoomModel>> {
  @override
  Future<List<RoomModel>> build() async => _fetch();

  Future<List<RoomModel>> _fetch() async {
    try {
      final response = await ApiClient.instance.get(ApiConstants.rooms);
      final list = (response.data['data'] as List?) ?? [];
      return list.map((j) => RoomModel.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> joinRoom(String roomId) async {
    try {
      await ApiClient.instance.post('\${ApiConstants.joinRoom}/\$roomId');
      await refresh();
    } catch (_) {}
  }
}
