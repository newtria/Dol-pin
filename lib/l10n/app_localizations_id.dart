// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'dol-pin';

  @override
  String get home => 'Beranda';

  @override
  String get explore => 'Jelajahi';

  @override
  String get chat => 'Obrolan';

  @override
  String get profile => 'my dol-pin';

  @override
  String get upcomingConcerts => 'Konser Mendatang';

  @override
  String get trendingItems => 'Item Populer';

  @override
  String get nearbyItems => 'Di Sekitar';

  @override
  String get login => 'Masuk';

  @override
  String get signup => 'Daftar';

  @override
  String get comingSoon => 'Segera hadir';

  @override
  String get pinItem => 'Pin';

  @override
  String get myPins => 'Pin Saya';

  @override
  String get tagline => 'Konsermu, satu tap saja.\nAman. Cepat. Lokal.';

  @override
  String get continueWithPhone => 'Lanjutkan dengan Telepon';

  @override
  String get phoneHint => 'Nomor telepon (+62...)';

  @override
  String get invalidPhoneFormat => 'Masukkan nomor telepon yang valid (contoh: +6281234567890)';

  @override
  String get or => 'atau';

  @override
  String get termsNotice => 'Dengan melanjutkan, Anda menyetujui Ketentuan Layanan';

  @override
  String get verify => 'Verifikasi';

  @override
  String get enterVerificationCode => 'Masukkan kode verifikasi';

  @override
  String sentTo(Object phone) {
    return 'Dikirim ke $phone';
  }

  @override
  String get invalidCode => 'Kode tidak valid. Silakan coba lagi.';

  @override
  String get resendCode => 'Kirim ulang kode';

  @override
  String get codeResent => 'Kode dikirim ulang';

  @override
  String get createProfile => 'Buat Profil';

  @override
  String get nickname => 'Nama panggilan';

  @override
  String get enterNickname => 'Masukkan nama panggilan';

  @override
  String get country => 'Negara';

  @override
  String get favoriteGroups => 'Grup Favorit (opsional)';

  @override
  String get typeAndEnter => 'Ketik dan tekan enter';

  @override
  String get getStarted => 'Mulai';

  @override
  String get messages => 'Pesan';

  @override
  String get noMessagesYet => 'Belum ada pesan';

  @override
  String get startConversation => 'Mulai percakapan dengan memesan sewa';

  @override
  String get messageHint => 'Pesan...';

  @override
  String get report => 'Laporkan';

  @override
  String get blockUser => 'Blokir Pengguna';

  @override
  String get startChatting => 'Mulai mengobrol';

  @override
  String get bookRental => 'Pesan Sewa';

  @override
  String get selectRentalDates => 'Pilih tanggal sewa';

  @override
  String get priceSummary => 'Ringkasan Harga';

  @override
  String rentalFeeLabel(Object price, Object days) {
    return 'Biaya sewa ($price x $days hari)';
  }

  @override
  String get depositRefundable => 'Deposit (dapat dikembalikan)';

  @override
  String get total => 'Total';

  @override
  String get escrowProtected => 'Dilindungi Escrow';

  @override
  String get escrowProtectedFull => 'Dilindungi Escrow - Deposit dikembalikan saat pengembalian';

  @override
  String get proceedToPayment => 'Lanjut ke Pembayaran';

  @override
  String get reservationCreated => 'Reservasi dibuat! Pemilik akan segera mengonfirmasi.';

  @override
  String get reservationFailed => 'Reservasi gagal';

  @override
  String get bookNow => 'Pesan Sekarang';

  @override
  String get perDay => '/ hari';

  @override
  String dayCount(num count) {
    return '$count hari';
  }

  @override
  String get searchHint => 'Cari item, konser, artis...';

  @override
  String get selectCategoryOrSearch => 'Pilih kategori atau cari\nuntuk menemukan sewaan';

  @override
  String get noItemsInCategory => 'Tidak ada item di kategori ini';

  @override
  String get couldNotLoadItems => 'Tidak dapat memuat item';

  @override
  String get couldNotLoadConcerts => 'Tidak dapat memuat konser';

  @override
  String get couldNotLoadMessages => 'Tidak dapat memuat pesan';

  @override
  String get noUpcomingConcerts => 'Tidak ada konser mendatang.\nCek lagi nanti!';

  @override
  String get registerItem => 'Daftarkan Item';

  @override
  String get category => 'Kategori';

  @override
  String get title => 'Judul';

  @override
  String get description => 'Deskripsi';

  @override
  String get condition => 'Kondisi';

  @override
  String get dailyPrice => 'Harga Harian';

  @override
  String get deposit => 'Deposit';

  @override
  String depositAmount(Object amount) {
    return 'Deposit: $amount';
  }

  @override
  String get pickupMethod => 'Metode Pengambilan';

  @override
  String get register => 'Daftar';

  @override
  String get photosRequired => 'Minimal 2 foto diperlukan';

  @override
  String get fillAllFields => 'Harap isi semua kolom yang diperlukan';

  @override
  String get validNumbers => 'Masukkan angka yang valid untuk harga dan deposit';

  @override
  String get settings => 'Pengaturan';

  @override
  String get myRentals => 'Sewa Saya';

  @override
  String get reviews => 'Ulasan';

  @override
  String get help => 'Bantuan';

  @override
  String get privacy => 'Kebijakan Privasi';

  @override
  String get lentOut => 'Dipinjamkan';

  @override
  String get borrowed => 'Dipinjam';

  @override
  String get notLoggedIn => 'Belum masuk';

  @override
  String get sendFailed => 'Gagal mengirim';

  @override
  String get errorLoadingMessages => 'Gagal memuat pesan';

  @override
  String get continueWithApple => 'Lanjutkan dengan Apple';

  @override
  String get continueWithGoogle => 'Lanjutkan dengan Google';

  @override
  String get appleSignInFailed => 'Login Apple gagal';

  @override
  String get googleSignInFailed => 'Login Google gagal';

  @override
  String errorPrefix(Object message) {
    return 'Error: $message';
  }

  @override
  String get countryKorea => 'Korea';

  @override
  String get countryIndonesia => 'Indonesia';

  @override
  String get countryJapan => 'Jepang';

  @override
  String get countryUS => 'Amerika Serikat';

  @override
  String get btVerified => 'BT Terverifikasi';

  @override
  String gradeLabel(Object grade) {
    return 'Grade $grade';
  }

  @override
  String get pickup => 'Pengambilan';

  @override
  String get available => 'Tersedia';

  @override
  String get photos => 'Foto';

  @override
  String photosCounter(Object count) {
    return '$count/10 (min 2)';
  }

  @override
  String get cover => 'Sampul';

  @override
  String get add => 'Tambah';

  @override
  String get titleHint => 'contoh: BTS Official Lightstick Ver.4';

  @override
  String get descriptionHint => 'Jelaskan kondisi, aksesoris yang termasuk...';

  @override
  String get conditionS => 'Seperti Baru';

  @override
  String get conditionSDesc => 'Tidak ada tanda pemakaian';

  @override
  String get conditionA => 'Sangat Baik';

  @override
  String get conditionADesc => 'Sedikit tanda pemakaian';

  @override
  String get conditionB => 'Baik';

  @override
  String get conditionBDesc => 'Bekas pakai tapi berfungsi';

  @override
  String get conditionC => 'Cukup';

  @override
  String get conditionCDesc => 'Pemakaian signifikan';

  @override
  String get categoryAll => 'Semua';

  @override
  String get categoryLightstick => 'Lightstick';

  @override
  String get categoryPhone => 'Telepon';

  @override
  String get categoryCamera => 'Kamera';

  @override
  String get categorySlogan => 'Slogan';

  @override
  String get categoryCostume => 'Kostum';

  @override
  String get categoryOther => 'Lainnya';

  @override
  String get logOut => 'Keluar';

  @override
  String get errorLoadingProfile => 'Gagal memuat profil';

  @override
  String get guest => 'Tamu';

  @override
  String get preferences => 'Preferensi';

  @override
  String get language => 'Bahasa';

  @override
  String get currency => 'Mata Uang';

  @override
  String get region => 'Wilayah';

  @override
  String get notifications => 'Notifikasi';

  @override
  String get pushNotifications => 'Notifikasi Push';

  @override
  String get chatNotifications => 'Notifikasi Chat';

  @override
  String get account => 'Akun';

  @override
  String get exportMyData => 'Ekspor Data Saya';

  @override
  String get downloadAsJson => 'Unduh sebagai JSON';

  @override
  String get deleteAccount => 'Hapus Akun';

  @override
  String get deleteAccountMessage => 'Ini akan menghapus akun dan semua data Anda secara permanen. Tidak dapat dibatalkan.';

  @override
  String get delete => 'Hapus';

  @override
  String get cancel => 'Batal';

  @override
  String get confirm => 'Konfirmasi';

  @override
  String appVersion(Object version) {
    return 'dol-pin v$version';
  }

  @override
  String get deleteAccountFailed => 'Gagal menghapus akun';

  @override
  String get langKorean => 'Korea';

  @override
  String get langEnglish => 'Inggris';

  @override
  String get langIndonesian => 'Indonesia';

  @override
  String get langJapanese => 'Jepang';

  @override
  String get currencyKRW => 'Won Korea (₩)';

  @override
  String get currencyIDR => 'Rupiah Indonesia (Rp)';

  @override
  String get currencyJPY => 'Yen Jepang (¥)';

  @override
  String get currencyUSD => 'Dolar AS (\$)';

  @override
  String get asLender => 'Sebagai Pemilik';

  @override
  String get asBorrower => 'Sebagai Penyewa';

  @override
  String get pleaseLogIn => 'Silakan masuk';

  @override
  String get noItemsRegistered => 'Belum ada item terdaftar.\nKetuk + untuk mendaftarkan item pertama!';

  @override
  String get noReservationsYet => 'Belum ada reservasi.\nJelajahi item untuk memulai!';

  @override
  String reportTitle(Object name) {
    return 'Laporkan $name';
  }

  @override
  String get selectReason => 'Pilih alasan:';

  @override
  String get reasonScam => 'Penipuan';

  @override
  String get reasonCounterfeit => 'Barang Palsu';

  @override
  String get reasonInappropriate => 'Konten Tidak Pantas';

  @override
  String get reasonOther => 'Lainnya';

  @override
  String get additionalDetails => 'Detail tambahan (opsional)';

  @override
  String get powerLender => 'Power Lender';

  @override
  String get regularLender => 'Regular Lender';

  @override
  String get newMember => 'Anggota Baru';

  @override
  String get userBlocked => 'Pengguna diblokir';

  @override
  String get userBlockFailed => 'Gagal memblokir pengguna';

  @override
  String get reportSubmitted => 'Laporan dikirim';

  @override
  String get reportFailed => 'Gagal mengirim laporan';

  @override
  String get datesOutsideAvailability => 'Tanggal yang dipilih di luar periode ketersediaan item';

  @override
  String get retry => 'Coba Lagi';

  @override
  String get pickupDirect => 'Bertemu Langsung';

  @override
  String get pickupDelivery => 'Pengiriman';

  @override
  String get pickupBoth => 'Keduanya';

  @override
  String get somethingWentWrong => 'Terjadi kesalahan';

  @override
  String get tryAgain => 'Coba lagi';

  @override
  String get bluetoothNotAvailable => 'Bluetooth tidak tersedia';

  @override
  String get noLightsticksFound => 'Tidak ada lightstick ditemukan';

  @override
  String get selectYourLightstick => 'Pilih lightstick Anda';

  @override
  String get scanning => 'Memindai...';

  @override
  String get verifyLightstick => 'Verifikasi Lightstick';

  @override
  String get autoTagging => 'Auto-tagging...';

  @override
  String get timeJustNow => 'baru saja';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes menit lalu';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours jam lalu';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days hari lalu';
  }

  @override
  String get pricePositiveRequired => 'Harga dan deposit harus lebih dari 0';

  @override
  String get share => 'Bagikan';

  @override
  String get linkCopied => 'Tautan disalin!';

  @override
  String get shareItem => 'Bagikan item';

  @override
  String checkOutThisItem(Object title, Object price) {
    return 'Lihat item ini di dol-pin! $title - $price/hari';
  }

  @override
  String shareConcert(Object title) {
    return 'Lihat konser ini di dol-pin! $title';
  }
}
