class ApiConstants {
  ApiConstants._();
  static const String baseUrl = 'https://api.mantraapp.in/api/v1';
  static const String register    = '/auth/register';
  static const String me          = '/auth/me';
  static const String refresh     = '/auth/refresh';
  static const String logout      = '/auth/logout';
  static const String fcmToken    = '/auth/fcm-token';
  static const String profile     = '/profile';
  static const String updateProfile = '/profile/update';
  static const String uploadVoice = '/profile/voice';
  static const String uploadPhoto = '/profile/photo';
  static const String dailySparks = '/match/sparks';
  static const String connect     = '/match/connect';
  static const String pass        = '/match/pass';
  static const String rooms       = '/rooms';
  static const String joinRoom    = '/rooms/join';
  static const String reportUser  = '/safety/report';
  static const String blockUser   = '/safety/block';
  static const String trustedContacts = '/safety/trusted-contacts';
  static const String sosAlert    = '/safety/sos';
  static const String createOrder = '/payment/order';
  static const String verifyPayment = '/payment/verify';
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 30000;
}
