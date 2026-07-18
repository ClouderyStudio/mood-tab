import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'preferences_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyReminderIdBase = 100;
  static const int _maxDailyReminderTimes = 10;
  static const int _medReminderIdBase = 200;
  static const int _maxMedReminders = 800; // 80 药物 × 10 时间点
  static const String _channelId = 'daily_reminder';
  static const String _channelName = '每日情绪记录提醒';
  static const String _medChannelId = 'medication_reminder';
  static const String _medChannelName = '用药提醒';

  bool _initialized = false;
  /// 缓存精确闹钟权限状态，避免重复尝试失败
  bool? _canUseExactAlarm;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _updateLocalTimeZone();
    _canUseExactAlarm = null; // 初始化时重置权限缓存
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;
  }

  /// 通知点击回调 — 确保应用被通知唤醒时能正确响应
  static void _onNotificationResponse(NotificationResponse response) {
    debugPrint('Notification tapped: id=${response.id}, payload=${response.payload}');
  }

  /// 根据用户设置的时区更新 tz.local
  void _updateLocalTimeZone() {
    final prefs = PreferencesService();
    final tzName = prefs.timeZone;
    try {
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    }
  }

  /// 用户更改时区后调用，重新初始化时区并重新调度通知
  Future<void> refreshTimeZone() async {
    _updateLocalTimeZone();
  }

  /// 检查通知权限是否已授予（不弹出系统对话框）
  Future<bool> areNotificationsEnabled() async {
    if (!_initialized) await init();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return await androidImpl.areNotificationsEnabled() ?? false;
    }
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final result = await iosImpl.checkPermissions();
      return result?.isEnabled ?? false;
    }
    return true;
  }

  /// 检查通知权限，未授予则申请
  /// 返回 true 表示当前已拥有通知权限
  Future<bool> ensurePermissions() async {
    if (!_initialized) await init();
    final hasPermission = await areNotificationsEnabled();
    if (hasPermission) return true;
    // 未授予，弹出系统权限申请对话框
    return requestPermissions();
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) await init();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      if (granted != null && !granted) return false;
    }
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(
        alert: true, badge: true, sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  Future<bool> requestExactAlarmPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      try {
        return await androidImpl.requestExactAlarmsPermission() ?? false;
      } catch (e) {
        debugPrint('requestExactAlarmsPermission error: $e');
        return false;
      }
    }
    return true;
  }

  /// 检查当前是否拥有精确闹钟权限（Android 12+）
  /// 返回 true 表示可以使用 exactAllowWhileIdle / alarmClock 模式
  Future<bool> canScheduleExactAlarms() async {
    if (!_initialized) await init();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true; // 非 Android 平台视为有权限
    try {
      return await androidImpl.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('canScheduleExactAlarms error: $e');
      return false;
    }
  }

  /// 检查是否拥有精确闹钟权限，没有则尝试请求
  /// 仅在闹钟模式下需要调用
  Future<bool> _ensureExactAlarm() async {
    // 如果已知没有权限，直接返回 false 避免重复尝试
    if (_canUseExactAlarm == false) return false;

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true; // 非 Android 平台
    try {
      final canSchedule = await androidImpl.canScheduleExactNotifications();
      if (canSchedule == true) {
        _canUseExactAlarm = true;
        return true;
      }
      // 没有精确闹钟权限，尝试请求
      final granted = await androidImpl.requestExactAlarmsPermission() ?? false;
      if (granted) {
        _canUseExactAlarm = true;
        return true;
      }
      // 请求后再次检查（用户可能已手动开启）
      final recheck = await androidImpl.canScheduleExactNotifications();
      if (recheck == true) {
        _canUseExactAlarm = true;
        return true;
      }
    } catch (e) {
      debugPrint('_ensureExactAlarm permission check error: $e');
    }
    // 确认无精确闹钟权限，标记并返回 false
    _canUseExactAlarm = false;
    return false;
  }

  /// 根据提醒风格选择调度模式
  /// 闹钟模式：需要精确闹钟权限，确保精准触发
  /// 通知模式：使用不精确模式即可，不主动请求精确闹钟权限
  AndroidScheduleMode _resolveScheduleMode(String stylePreference, bool hasExactAlarm) {
    if (stylePreference == 'alarm' && hasExactAlarm) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    // 通知模式或闹钟模式但无精确闹钟权限：使用不精确模式
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  AndroidNotificationDetails _androidDetails({
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String stylePreference,
  }) {
    if (stylePreference == 'alarm') {
      return AndroidNotificationDetails(
        channelId, channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@drawable/ic_notification',
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
      );
    }
    return AndroidNotificationDetails(
      channelId, channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      visibility: NotificationVisibility.public,
    );
  }

  DarwinNotificationDetails _iosDetails(String stylePreference) {
    if (stylePreference == 'alarm') {
      // 闹钟模式：时间敏感级别，可穿透专注模式
      return const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
    }
    return const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
  }

  Future<void> scheduleDailyReminder(List<String> times) async {
    if (!_initialized) await init();
    final hasExactAlarm = await _ensureExactAlarm();
    await cancelDailyReminders();

    final prefs = PreferencesService();
    final stylePref = prefs.dailyReminderStyle;
    final androidDetails = _androidDetails(
      channelId: _channelId,
      channelName: _channelName,
      channelDescription: '每天定时提醒你记录情绪',
      stylePreference: stylePref,
    );
    final iosDetails = _iosDetails(stylePref);
    final details = NotificationDetails(
      android: androidDetails, iOS: iosDetails,
    );

    var scheduleMode = _resolveScheduleMode(stylePref, hasExactAlarm);

    for (int i = 0; i < times.length && i < _maxDailyReminderTimes; i++) {
      final parts = times[i].split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      try {
        await _plugin.zonedSchedule(
          _dailyReminderIdBase + i,
          '记录此刻的心情 🌿',
          '花一分钟，写下今天的情绪吧',
          scheduled,
          details,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } on PlatformException catch (e) {
        if (e.code == 'exact_alarms_not_permitted' &&
            scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle) {
          // 原生层拒绝精确闹钟，回退到不精确模式重新调度
          _canUseExactAlarm = false;
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
          await _plugin.zonedSchedule(
            _dailyReminderIdBase + i,
            '记录此刻的心情 🌿',
            '花一分钟，写下今天的情绪吧',
            scheduled,
            details,
            androidScheduleMode: scheduleMode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        } else {
          debugPrint('scheduleDailyReminder failed id=${_dailyReminderIdBase + i} code=${e.code}: $e');
          // 非精确闹钟错误：记录日志，继续调度下一个时间点
        }
      }
    }
  }

  Future<void> cancelDailyReminders() async {
    for (int i = 0; i < _maxDailyReminderTimes; i++) {
      await _plugin.cancel(_dailyReminderIdBase + i);
    }
  }

  // ==================== 药物提醒 ====================

  Future<void> scheduleMedicationReminder({
    required int notificationId,
    required String name,
    required String dosage,
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) await init();
    final hasExactAlarm = await _ensureExactAlarm();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, hour, minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final prefs = PreferencesService();
    final stylePref = prefs.medicationReminderStyle;
    final androidDetails = _androidDetails(
      channelId: _medChannelId,
      channelName: _medChannelName,
      channelDescription: '药物服用提醒',
      stylePreference: stylePref,
    );
    final iosDetails = _iosDetails(stylePref);
    final details = NotificationDetails(
      android: androidDetails, iOS: iosDetails,
    );

    var scheduleMode = _resolveScheduleMode(stylePref, hasExactAlarm);

    try {
      await _plugin.zonedSchedule(
        notificationId,
        '该吃药了 💊 $name',
        '剂量：$dosage · 记得按时服药哦',
        scheduled,
        details,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted' &&
          scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle) {
        // 原生层拒绝精确闹钟，回退到不精确模式重新调度
        _canUseExactAlarm = false;
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        await _plugin.zonedSchedule(
          notificationId,
          '该吃药了 💊 $name',
          '剂量：$dosage · 记得按时服药哦',
          scheduled,
          details,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } else {
        debugPrint('scheduleMedicationReminder failed id=$notificationId code=${e.code}: $e');
        // 非精确闹钟错误：记录日志，不中断后续药物调度
      }
    }
  }

  Future<void> cancelMedicationReminder(int medIndex) async {
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(_medReminderIdBase + medIndex * 10 + i);
    }
  }

  /// 取消所有药物提醒（不影响每日提醒）
  Future<void> cancelAllMedicationReminders() async {
    // 只取消药物提醒范围内的 ID（200~999），避免误删每日提醒（100~109）
    for (int i = 0; i < _maxMedReminders; i++) {
      await _plugin.cancel(_medReminderIdBase + i);
    }
  }
}
