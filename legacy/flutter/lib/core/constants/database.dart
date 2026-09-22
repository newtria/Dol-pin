/// Centralized table and storage bucket names.
/// Single source of truth — never hardcode these elsewhere.
class DbTables {
  static const users = 'users';
  static const publicUserProfiles = 'public_user_profiles';
  static const concerts = 'concerts';
  static const rentalItems = 'rental_items';
  static const reservations = 'reservations';
  static const chatMessages = 'chat_messages';
  static const reviews = 'reviews';
  static const reports = 'reports';
  static const userBlocks = 'user_blocks';
  static const chatRooms = 'chat_rooms';
}

class StorageBuckets {
  static const rentalPhotos = 'rental-photos';
  static const profilePhotos = 'profile-photos';
  static const chatImages = 'chat-images';
}

class DbFunctions {
  static const getChatList = 'get_chat_list';
  static const getOrCreateRoom = 'get_or_create_room';
  static const createReservationIntent = 'create_reservation_intent';
  static const transitionReservationStatus = 'transition_reservation_status';
  static const confirmReservationReturn = 'confirm_reservation_return';
  static const startReservationPaymentAttempt =
      'start_reservation_payment_attempt';
}

class AppConstants {
  static const oauthCallbackUrl = 'com.dolpin.app://callback';
}
