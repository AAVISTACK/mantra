import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';

abstract class AuthRepository {
  Future<String> sendOtp(String phoneNumber);
  Future<bool> verifyOtp(String verificationId, String otp);
  Future<UserModel?> getCurrentUser();
  Future<void> logout();
  Future<void> saveFcmToken(String token);
}

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FlutterSecureStorage _secureStorage;

  AuthRepositoryImpl({
    required FirebaseAuth firebaseAuth,
    required FlutterSecureStorage secureStorage,
  })  : _firebaseAuth = firebaseAuth,
        _secureStorage = secureStorage;

  @override
  Future<String> sendOtp(String phoneNumber) async {
    final completer = Completer<String>();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: '+91\$phoneNumber',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _firebaseAuth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(e.message ?? 'Phone verification failed'));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      timeout: const Duration(seconds: 60),
    );

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('OTP request timed out'),
    );
  }

  @override
  Future<bool> verifyOtp(String verificationId, String otp) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final result = await _firebaseAuth.signInWithCredential(credential);
      if (result.user == null) return false;
      final idToken = await result.user!.getIdToken(true);
      if (idToken == null) return false;
      await _secureStorage.write(key: 'firebase_token', value: idToken);
      await _registerWithBackend(idToken);
      return true;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'OTP verification failed');
    }
  }

  Future<void> _registerWithBackend(String firebaseToken) async {
    final response = await ApiClient.instance.post(
      ApiConstants.register,
      options: ApiClient.authHeader(firebaseToken),
    );
    final jwt     = response.data['data']['access_token'] as String;
    final refresh = response.data['data']['refresh_token'] as String;
    await _secureStorage.write(key: 'jwt_token', value: jwt);
    await _secureStorage.write(key: 'refresh_token', value: refresh);
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final jwt = await _secureStorage.read(key: 'jwt_token');
      if (jwt == null) return null;
      final response = await ApiClient.instance.get(ApiConstants.me);
      return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try { await ApiClient.instance.post(ApiConstants.logout); } catch (_) {}
    await _firebaseAuth.signOut();
    await _secureStorage.deleteAll();
  }

  @override
  Future<void> saveFcmToken(String token) async {
    try {
      await ApiClient.instance.post(ApiConstants.fcmToken, data: {'fcm_token': token});
    } catch (_) {}
  }
}
