import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'pages/calendar_page.dart';
import 'pages/stats_page.dart';
import 'pages/settings_page.dart';
import 'pages/mood_record_page.dart';
import 'pages/splash_page.dart';
import 'pages/privacy_lock_page.dart';
import 'providers/mood_provider.dart';
import 'services/preferences_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MoodTabApp());
}

class MoodTabApp extends StatelessWidget {
  const MoodTabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MoodProvider(),
      child: Consumer<MoodProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: '脑电波',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: provider.themeMode == 'dark'
                ? ThemeMode.dark
                : provider.themeMode == 'system'
                    ? ThemeMode.system
                    : ThemeMode.light,
            home: const _AppEntrance(),
          );
        },
      ),
    );
  }
}

/// 启动入口：先显示 SplashPage，加载完成后切换到主页
class _AppEntrance extends StatefulWidget {
  const _AppEntrance();

  @override
  State<_AppEntrance> createState() => _AppEntranceState();
}

class _AppEntranceState extends State<_AppEntrance>
    with WidgetsBindingObserver {
  final PreferencesService _preferences = PreferencesService();
  final NotificationService _notifications = NotificationService();
  bool _showSplash = true;
  bool _isLocked = false;
  bool _preferencesReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MoodProvider>().loadAllData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_preferencesReady || _showSplash) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final hasValidPin = _preferences.pinCode.length == 4;
      if (_preferences.privacyLockEnabled && hasValidPin && !_isLocked) {
        setState(() => _isLocked = true);
      }
    }
  }

  Future<void> _onSplashDone() async {
    final provider = context.read<MoodProvider>();
    // 等待 provider 加载完成，不再依赖 totalCount 条件
    int retries = 0;
    while (provider.isLoading && retries < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      retries++;
    }
    if (!mounted) return;

    try {
      await _preferences.init();
      await _notifications.init();
      // 先检查通知权限是否已授予，未授予才申请
      await _notifications.ensurePermissions();
    } catch (e) {
      debugPrint('Initialization error: $e');
    }

    // 检查精确闹钟权限，未授予才申请
    try {
      final hasExactAlarm = await _notifications.canScheduleExactAlarms();
      if (!hasExactAlarm) {
        final granted = await _notifications.requestExactAlarmPermission();
        if (!granted) {
          debugPrint('Exact alarm permission denied by user');
        }
      }
    } catch (e) {
      debugPrint('Request exact alarm permission error: $e');
    }

    if (!mounted) return;
    setState(() {
      _showSplash = false;
      _preferencesReady = true;
    });

    // 通知调度在后台异步执行，不阻塞 UI 启动
    _scheduleNotificationsInBackground(provider);
  }

  /// 后台异步调度通知，避免阻塞主页启动
  void _scheduleNotificationsInBackground(MoodProvider provider) async {
    try {
      if (_preferences.dailyReminderEnabled &&
          _preferences.dailyReminderTimes.isNotEmpty) {
        await _notifications.scheduleDailyReminder(
            _preferences.dailyReminderTimes);
      }
      // 启动时重新调度所有药物提醒（应对设备重启等场景）
      await provider.rescheduleMedicationReminders();
    } catch (e) {
      debugPrint('Schedule notification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashPage(onAnimationEnd: _onSplashDone);
    }
    if (_isLocked) {
      return PrivacyLockPage(
        expectedPin: _preferences.pinCode,
        onUnlocked: () => setState(() => _isLocked = false),
      );
    }
    return const MainScaffold();
  }
}

/// 主框架 - 底部导航
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    CalendarPage(),
    StatsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomBarColor = isDark ? AppTheme.darkCardBg : AppTheme.cardBg;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const MoodRecordPage(),
            ),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 0,
        color: bottomBarColor,
        surfaceTintColor: Colors.transparent,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, '今日'),
              _buildNavItem(
                  1, Icons.calendar_month_outlined, Icons.calendar_month, '日历'),
              const SizedBox(width: 48),
              _buildNavItem(2, Icons.bar_chart_outlined, Icons.bar_chart, '统计'),
              _buildNavItem(3, Icons.person_outline, Icons.person, '我的'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppTheme.primaryColor;
    final inactiveColor = isDark ? AppTheme.darkTextHint : AppTheme.textHint;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? activeColor : inactiveColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
