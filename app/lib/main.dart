import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/firebase_service.dart';
import 'screens/home_screen.dart';
import 'screens/find_ride_screen.dart';
import 'screens/create_ride_screen.dart';
import 'screens/my_rides_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

final womenOnlyProvider = StateProvider<bool>((ref) => false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FirebaseService.initialize();
  } catch (e) {
    // Allow running in environments without google-services files (dev/CI).
    // Developer should ensure `google-services.json` / `GoogleService-Info.plist` are present for full Firebase functionality.
    // Log to console for visibility.
    // ignore: avoid_print
    print('Firebase init warning: $e');
  }

  runApp(const ProviderScope(child: RaahiApp()));
}

class RaahiApp extends ConsumerStatefulWidget {
  const RaahiApp({Key? key}) : super(key: key);

  @override
  ConsumerState<RaahiApp> createState() => _RaahiAppState();
}

class _RaahiAppState extends ConsumerState<RaahiApp> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animController;

  final List<Widget> _pages = const [
    HomeScreen(),
    FindRideScreen(),
    CreateRideScreen(),
    MyRidesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final womenOnly = ref.watch(womenOnlyProvider);

    final ThemeData base = ThemeData(
      primaryColor: const Color(0xFF7C3AED),
      scaffoldBackgroundColor: const Color(0xFFF3E8FF),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED)),
      useMaterial3: true,
    );

    final ThemeData womenTheme = ThemeData(
      primaryColor: const Color(0xFFFFE6F2),
      scaffoldBackgroundColor: const Color(0xFFFFE6F2),
      cardColor: const Color(0xFFFFF0F6),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFE6F2)),
      useMaterial3: true,
    );

    // animate controller when womenOnly toggles
    if (womenOnly) {
      _animController.forward();
    } else {
      _animController.reverse();
    }

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: womenOnly ? womenTheme : base,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData) {
                return const AuthScreen();
              }

              return Scaffold(
                body: _pages[_selectedIndex],
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => _selectedIndex = 2),
                  backgroundColor: womenOnly ? const Color(0xFFFFC0DC) : const Color(0xFF7C3AED),
                  child: const Icon(Icons.add, size: 28),
                ),
                floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
                bottomNavigationBar: BottomAppBar(
                  shape: const CircularNotchedRectangle(),
                  notchMargin: 6,
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.home),
                          onPressed: () => setState(() => _selectedIndex = 0),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => setState(() => _selectedIndex = 1),
                        ),
                        const SizedBox(width: 56),
                        IconButton(
                          icon: const Icon(Icons.directions_car),
                          onPressed: () => setState(() => _selectedIndex = 3),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person),
                          onPressed: () => setState(() => _selectedIndex = 4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
