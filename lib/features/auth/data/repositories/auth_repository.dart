import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

import '../models/user_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';

abstract class AuthRepository {
  Future<String?> sendOtp(String phoneNumber);
  Future<bool> verifyOtp(String verificationId, String otp);
  Future<UserModel?> getCurrentUser();
  Future<void> logout();
}

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FlutterSecureStorage _secureStorage;

  AuthRepositoryImpl({
    required FirebaseAuth firebaseAuth,
    required FlutterSecureStorage secureStorage,
  })  : _firebaseAuth = firebaseAuth,
        _secureStorage = secureStorage;

  String? _verificationId;

  @override
  Future<String?> sendOtp(String phoneNumber) async {
    String? resolvedVerificationId;

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: '+91$phoneNumber',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _firebaseAuth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        throw Exception(e.message);
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        resolvedVerificationId = verificationId;
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );

    // Wait for codeSent
    await Future.delayed(const Duration(milliseconds: 500));
    return _verificationId;
  }

  @override
  Future<bool> verifyOtp(String verificationId, String otp) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final result = await _firebaseAuth.signInWithCredential(credential);
      if (result.user != null) {
        final idToken = await result.user!.getIdToken();
        await _secureStorage.write(key: 'firebase_token', value: idToken);

        // Register/login with our backend
        await _registerWithBackend(idToken!);
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('OTP verification failed: $e');
    }
  }

  Future<void> _registerWithBackend(String firebaseToken) async {
    try {
      final dio = Dio();
      final response = await dio.post(
        '${ApiConstants.baseUrl}/auth/register',
        options: Options(
          headers: {'Authorization': 'Bearer $firebaseToken'},
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jwt = response.data['data']['access_token'];
        await _secureStorage.write(key: 'jwt_token', value: jwt);
      }
    } catch (e) {
      // If backend registration fails, we still have Firebase auth
      rethrow;
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final jwt = await _secureStorage.read(key: 'jwt_token');
      if (jwt == null) return null;

      final dio = Dio();
      final response = await dio.get(
        '${ApiConstants.baseUrl}/auth/me',
        options: Options(
          headers: {'Authorization': 'Bearer $jwt'},
        ),
      );
      return UserModel.fromJson(response.data['data']);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await _secureStorage.deleteAll();
  }
}
