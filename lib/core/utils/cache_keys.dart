class CacheKeys {
  static String upcomingConcerts(String? country) =>
      'concerts_upcoming_${country ?? 'all'}';
  static String userProfile(String userId) => 'user_profile_$userId';
  static const Duration concertsTtl = Duration(minutes: 30);
  static const Duration profileTtl = Duration(hours: 1);
}
