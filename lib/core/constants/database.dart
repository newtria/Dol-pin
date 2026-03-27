/// Centralized table and storage bucket names.
/// Single source of truth — never hardcode these elsewhere.
class DbTables {
  static const users = 'users';
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
}

class AppConstants {
  static const oauthCallbackUrl = 'com.dolpin.app://callback';
}
