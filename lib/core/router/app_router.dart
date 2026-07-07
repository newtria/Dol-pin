import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../constants/app_colors.dart';
import '../constants/database.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_room_screen.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/explore/screens/item_detail_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/profile/screens/my_rentals_screen.dart';
import '../../features/register/screens/register_item_screen.dart';
import '../../features/reservation/screens/reservation_detail_screen.dart';
import '../../features/reservation/screens/reservation_screen.dart';

/// Bridges a [Stream] into a [Listenable] so GoRouter re-evaluates its
/// `redirect` callback every time Supabase emits a new [AuthState] event
/// (sign-in / sign-out / token refresh / recovery).
///
/// Without this, the router only re-checks auth when the user manually
/// navigates — a silent sign-out would leave a stale authed screen visible.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

const _loginPath = '/login';
const _otpPath = '/otp';
const _signupPath = '/signup';

final _profileCompletionCache = <String, bool>{};

Future<bool?> _profileExists(SupabaseClient client, String userId) async {
  if (_profileCompletionCache[userId] == true) return true;

  try {
    final row = await client
        .from(DbTables.users)
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    final exists = row != null;
    if (exists) _profileCompletionCache[userId] = true;
    return exists;
  } catch (_) {
    // Fail open on transient profile lookup errors so navigation does not trap
    // an already-onboarded user behind the signup screen while offline.
    return null;
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  // GoRouter redirect runs outside Riverpod scope, so direct Supabase
  // access is acceptable here — this is the only allowed exception.
  refreshListenable: _GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final path = state.uri.path;
    final isAuth = session != null;
    final isLoginOrOtp = path == _loginPath || path == _otpPath;
    final isSignup = path == _signupPath;
    final isAuthRoute = isLoginOrOtp || isSignup;

    if (!isAuth && !isAuthRoute) return _loginPath;
    if (!isAuth) return null;
    if (isLoginOrOtp) return '/';

    final hasProfile = await _profileExists(client, session.user.id);
    if (hasProfile == false) return isSignup ? null : _signupPath;
    if (hasProfile == true && isSignup) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/otp',
      name: 'otp',
      builder: (context, state) =>
          OtpScreen(phone: state.uri.queryParameters['phone'] ?? ''),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignupScreen(),
    ),

    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/explore',
          name: 'explore',
          builder: (context, state) =>
              ExploreScreen(concertId: state.uri.queryParameters['concertId']),
        ),
        GoRoute(
          path: '/chat',
          name: 'chat',
          builder: (context, state) => const ChatListScreen(),
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    GoRoute(
      path: '/item/:id',
      name: 'itemDetail',
      builder: (context, state) =>
          ItemDetailScreen(itemId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/reserve/:itemId',
      name: 'reserve',
      builder: (context, state) =>
          ReservationScreen(itemId: state.pathParameters['itemId']!),
    ),
    GoRoute(
      path: '/reservation/:id',
      name: 'reservationDetail',
      builder: (context, state) =>
          ReservationDetailScreen(reservationId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/chat/:roomId/:userId',
      name: 'chatRoom',
      builder: (context, state) => ChatRoomScreen(
        otherUserId: state.pathParameters['userId']!,
        otherUserName:
            state.uri.queryParameters['name'] ??
            AppLocalizations.of(context)!.guest,
        roomId: state.pathParameters['roomId']!,
      ),
    ),
    GoRoute(
      path: '/register-item',
      name: 'registerItem',
      builder: (context, state) => const RegisterItemScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/my-rentals',
      name: 'myRentals',
      builder: (context, state) => const MyRentalsScreen(),
    ),
  ],
);

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static int _indexFromLocation(String location) {
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/chat')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed('registerItem'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.push_pin),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFromLocation(location),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.goNamed('home');
            case 1:
              context.goNamed('explore');
            case 2:
              context.goNamed('chat');
            case 3:
              context.goNamed('profile');
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: l.explore,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: l.chat,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_outline),
            selectedIcon: const Icon(Icons.bookmark),
            label: l.profile,
          ),
        ],
      ),
    );
  }
}
