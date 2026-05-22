import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../data/models/spark_model.dart';

abstract class SparksRepository {
  Future<List<SparkModel>> getDailySparks();
  Future<bool> connectSpark(String targetUserId);
  Future<void> passSpark(String targetUserId);
}

class SparksRepositoryImpl extends SparksRepository {
  @override
  Future<List<SparkModel>> getDailySparks() async {
    final response = await ApiClient.instance.get(ApiConstants.dailySparks);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((j) => SparkModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<bool> connectSpark(String targetUserId) async {
    final response = await ApiClient.instance.post(
      ApiConstants.connect, data: {'target_user_id': targetUserId},
    );
    return response.data['data']['is_mutual'] as bool? ?? false;
  }

  @override
  Future<void> passSpark(String targetUserId) async {
    await ApiClient.instance.post(ApiConstants.pass, data: {'target_user_id': targetUserId});
  }
}
