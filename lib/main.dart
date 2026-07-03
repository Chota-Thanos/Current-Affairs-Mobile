import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/navigation_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ApiClient(),
      child: const CurrentAffairsProApp(),
    ),
  );
}

class CurrentAffairsProApp extends StatelessWidget {
  const CurrentAffairsProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Current Affairs Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = Provider.of<ApiClient>(context);

    // Show beautiful premium splash/loading screen while checking auth cache state
    if (!apiClient.isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        body: Container(
          decoration: const BoxDecoration(
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
                    color: Colors.white,
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
