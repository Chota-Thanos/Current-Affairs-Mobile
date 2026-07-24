import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import 'dashboard_home_screen.dart';
import '../../current_affairs/presentation/daily_news_feed_screen.dart';
import '../../workspace/presentation/notes_space_dashboard_screen.dart';
import '../../workspace/presentation/workspace_ai_helper_screen.dart';
import '../../../../core/utils/auth_interception_helper.dart';

class NavigationHome extends StatefulWidget {
  const NavigationHome({super.key});

  @override
  State<NavigationHome> createState() => NavigationHomeState();
}

class NavigationHomeState extends State<NavigationHome> {
  int _currentIndex = 0;
  final GlobalKey<DailyNewsFeedScreenState> prelimsKey = GlobalKey<DailyNewsFeedScreenState>();
  final GlobalKey<DailyNewsFeedScreenState> mainsKey = GlobalKey<DailyNewsFeedScreenState>();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardHomeScreen(onNavigate: changeTab),
      DailyNewsFeedScreen(key: prelimsKey, initialTab: 0),
      DailyNewsFeedScreen(key: mainsKey, initialTab: 1),
      const NotesSpaceDashboardScreen(),
      const WorkspaceAiHelperScreen(),
    ];
  }

  void changeTab(int index, {String? subjectName}) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 1) {
      Future.delayed(const Duration(milliseconds: 50), () {
        prelimsKey.currentState?.applyExternalFilters(subjectName: subjectName);
      });
    } else if (index == 2) {
      Future.delayed(const Duration(milliseconds: 50), () {
        mainsKey.currentState?.applyExternalFilters(subjectName: subjectName);
      });
    }
  }

  void _showThemeChooser(BuildContext context) {
    final controller = Provider.of<ThemeController>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        Widget option(String label, IconData icon, ThemeMode mode, String subtitle) {
          final selected = controller.mode == mode;
          return ListTile(
            leading: Icon(icon, color: selected ? AppColors.civic : AppColors.muted),
            title: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.civic : AppColors.ink,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
            ),
            trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.civic) : null,
            onTap: () {
              controller.setMode(mode);
              Navigator.pop(sheetContext);
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Appearance",
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
              ),
              option("System default", Icons.brightness_auto_outlined, ThemeMode.system,
                  "Match your device's light/dark setting"),
              option("Light", Icons.light_mode_outlined, ThemeMode.light, "Always use the light theme"),
              option("Dark", Icons.dark_mode_outlined, ThemeMode.dark, "Always use the dark theme"),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = Provider.of<ApiClient>(context);
    final username = apiClient.user?['username'] ?? 'Student';

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: AppColors.ink),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          "Current Affairs Pro",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.brandNavy,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: AppColors.ink),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No new notifications")),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.line.withValues(alpha: 0.5),
            height: 1.0,
          ),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: AppColors.brandNavy,
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.surface,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'S',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              accountName: Text(
                username,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              accountEmail: Text(
                apiClient.user?['email'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_rounded),
              title: const Text("Home"),
              selected: _currentIndex == 0,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chrome_reader_mode_rounded),
              title: const Text("Prelims"),
              selected: _currentIndex == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_edu_rounded),
              title: const Text("Mains"),
              selected: _currentIndex == 2,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_shared_rounded),
              title: const Text("My Notes"),
              selected: _currentIndex == 3,
              onTap: () {
                Navigator.pop(context);
                if (apiClient.isGuestMode) {
                  AuthInterceptionHelper.checkAuthAndPrompt(context, apiClient);
                  return;
                }
                setState(() => _currentIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology_rounded),
              title: const Text("AI Helper"),
              selected: _currentIndex == 4,
              onTap: () {
                Navigator.pop(context);
                if (apiClient.isGuestMode) {
                  AuthInterceptionHelper.checkAuthAndPrompt(context, apiClient);
                  return;
                }
                setState(() => _currentIndex = 4);
              },
            ),
            ListTile(
              leading: Icon(Icons.brightness_6_outlined, color: AppColors.brandNavy),
              title: const Text("Appearance"),
              onTap: () {
                Navigator.pop(context);
                _showThemeChooser(context);
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.berry),
              title: const Text("Sign Out", style: TextStyle(color: AppColors.berry)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return dialogBuilder(context, apiClient);
                  },
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.brandNavy.withValues(alpha: 0.08),
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            if ((index == 3 || index == 4) && apiClient.isGuestMode) {
              AuthInterceptionHelper.checkAuthAndPrompt(context, apiClient);
              return;
            }
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: _currentIndex == 0 ? AppColors.brandNavy : AppColors.muted),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.brandNavy),
              label: "Home",
            ),
            NavigationDestination(
              icon: Icon(Icons.chrome_reader_mode_outlined, color: _currentIndex == 1 ? AppColors.brandNavy : AppColors.muted),
              selectedIcon: Icon(Icons.chrome_reader_mode_rounded, color: AppColors.brandNavy),
              label: "Prelims",
            ),
            NavigationDestination(
              icon: Icon(Icons.history_edu_outlined, color: _currentIndex == 2 ? AppColors.brandNavy : AppColors.muted),
              selectedIcon: Icon(Icons.history_edu_rounded, color: AppColors.brandNavy),
              label: "Mains",
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_shared_outlined, color: _currentIndex == 3 ? AppColors.brandNavy : AppColors.muted),
              selectedIcon: Icon(Icons.folder_shared_rounded, color: AppColors.brandNavy),
              label: "My Notes",
            ),
            NavigationDestination(
              icon: Icon(Icons.psychology_outlined, color: _currentIndex == 4 ? AppColors.brandNavy : AppColors.muted),
              selectedIcon: Icon(Icons.psychology_rounded, color: AppColors.brandNavy),
              label: "AI Helper",
            ),
          ],
        ),
      ),
    );
  }

  Widget dialogBuilder(BuildContext context, ApiClient apiClient) {
    return AlertDialog(
      title: Text("Sign Out", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      content: const Text("Are you sure you want to sign out of Current Affairs Pro?"),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            apiClient.logout();
          },
          child: const Text("Sign Out", style: TextStyle(color: AppColors.berry)),
        ),
      ],
    );
  }
}
