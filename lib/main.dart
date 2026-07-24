import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/navigation_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the saved theme preference before the first frame to avoid a flash.
  final themeController = ThemeController();
  await themeController.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiClient()),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
      ],
      child: const CurrentAffairsProApp(),
    ),
  );
}

class CurrentAffairsProApp extends StatelessWidget {
  const CurrentAffairsProApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    return MaterialApp(
      title: 'Current Affairs Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.mode,
      builder: (context, child) {
        // Keep the theme-aware AppColors tokens in sync with whichever theme
        // (light/dark) the app resolved to — including OS-driven changes.
        AppColors.brightness = Theme.of(context).brightness;
        return child ?? const SizedBox.shrink();
      },
      home: const AuthWrapper(),
    );
  }
}

/// Root auth gate that also refreshes entitlements whenever the app returns to
/// the foreground.
///
/// Purchases happen on the website in an external browser, so without this a
/// user who has just paid comes back to an app that still shows content locked
/// — until they fully restart or log out and back in.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    if (!apiClient.isAuthenticated) return;
    // Fire-and-forget: a failed refresh must never block the UI.
    apiClient.syncEntitlements();
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = Provider.of<ApiClient>(context);

    // Show beautiful premium splash/loading screen while checking auth cache state
    if (!apiClient.isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.6),
              radius: 1.2,
              colors: [
                Color(0x154285F4),
                Color(0x02A855F7),
                AppColors.paper,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.line, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        offset: Offset(0, 4),
                        blurRadius: 16,
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.newspaper_rounded,
                    size: 44,
                    color: AppColors.civic,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Current Affairs Pro",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Coaching Hub Student Edition",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.civic,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Switch between authenticated/guest and unauthenticated screens
    if (apiClient.isAuthenticated || apiClient.isGuestMode) {
      return const NavigationHome();
    } else {
      return const LoginScreen();
    }
  }
}
