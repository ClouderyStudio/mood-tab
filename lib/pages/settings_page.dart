import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/mood_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/mood_provider.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'about_page.dart';
import 'software_info_page.dart';
import 'assessment_web_page.dart';
import 'qisoul_web_page.dart';
import 'crisis_support_page.dart';
import 'urge_log_page.dart';
import 'medication_reminder_page.dart';
import 'tag_management_page.dart';
import 'warm_words_page.dart';

/// 设置页（我的）
/// 个人信息、提醒设置、隐私锁、主题设置、数据管理、心理测评、关于作者
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _prefs = PreferencesService();
  final _dbService = DatabaseService();
  final _notifications = NotificationService();

  bool _reminderEnabled = false;
  List<String> _reminderTimes = ['20:00'];
  bool _privacyLockEnabled = false;
  String _themeMode = 'light';
  String _version = '';
  String _dailyReminderStyle = 'notification';
  String _medicationReminderStyle = 'notification';
  bool _hasExactAlarmPermission = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final packageInfo = await PackageInfo.fromPlatform();
    await _prefs.init();
    await _checkExactAlarmPermission();
    setState(() {
      _reminderEnabled = _prefs.dailyReminderEnabled;
      _reminderTimes = _prefs.dailyReminderTimes;
      _privacyLockEnabled = _prefs.privacyLockEnabled;
      _themeMode = _prefs.themeMode;
      _version = '脑电波 v${packageInfo.version}';
      _dailyReminderStyle = _prefs.dailyReminderStyle;
      _medicationReminderStyle = _prefs.medicationReminderStyle;
    });
  }

  /// 检查精确闹钟权限状态，用于 UI 提示
  Future<void> _checkExactAlarmPermission() async {
    try {
      final hasPermission = await _notifications.canScheduleExactAlarms();
      if (mounted) {
        setState(() => _hasExactAlarmPermission = hasPermission);
      }
    } catch (e) {
      debugPrint('Check exact alarm permission error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<MoodProvider>(
          builder: (context, provider, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    '我的',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),

                  // 个人信息卡片
                  _buildProfileCard(provider),
                  const SizedBox(height: 24),

                  // 提醒设置
                  _buildSectionTitle('提醒设置'),
                  const SizedBox(height: 8),
                  _buildReminderSection(),
                  const SizedBox(height: 24),

                  // 隐私锁
                  _buildSectionTitle('隐私与安全'),
                  const SizedBox(height: 8),
                  _buildPrivacySection(),
                  const SizedBox(height: 24),

                  // 主题设置
                  _buildSectionTitle('主题设置'),
                  const SizedBox(height: 8),
                  _buildThemeSection(),
                  const SizedBox(height: 24),

                  // 个性化
                  _buildSectionTitle('个性化'),
                  const SizedBox(height: 8),
                  _buildPersonalizationSection(),
                  const SizedBox(height: 24),

                  // 数据管理
                  _buildSectionTitle('数据管理'),
                  const SizedBox(height: 8),
                  _buildDataManagementSection(),
                  const SizedBox(height: 24),

                  // 心理测评
                  _buildSectionTitle('更多'),
                  const SizedBox(height: 8),
                  _buildMoreSection(),
                  const SizedBox(height: 24),

                  // 关于作者
                  _buildSectionTitle('关于'),
                  const SizedBox(height: 8),
                  _buildAboutSection(),

                  const SizedBox(height: 32),
                  // 版本信息
                  Center(
                    child: Text(
                      _version,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textHintOf(context),
                          ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==================== 个人信息卡片 ====================

  Widget _buildProfileCard(MoodProvider provider) {
    final userName = provider.userName;
    final displayName = userName.isNotEmpty ? userName : '点击设置昵称';

    return GestureDetector(
      onTap: () => _editUserName(),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryLight,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // 头像（有昵称时显示首字，否则显示默认图标）
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: userName.isNotEmpty
                    ? Text(
                        userName.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 36,
                        color: Colors.white,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // 昵称 + 统计信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildStatItem(
                        '${provider.totalCount}',
                        '记录总数',
                      ),
                      const SizedBox(width: 24),
                      _buildStatItem(
                        '${provider.checkinStreak}',
                        '连续打卡',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  // ==================== 分区标题 ====================

  /// 编辑用户昵称
  Future<void> _editUserName() async {
    final provider = context.read<MoodProvider>();
    final controller = TextEditingController(text: provider.userName);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('设置昵称'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 12,
            decoration: const InputDecoration(
              hintText: '请输入你的昵称',
              counterText: '',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              // 实时更新不需要，点击保存时读取
            },
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            if (provider.userName.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop('__clear__');
                },
                child: const Text('清除'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(controller.text.trim());
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == '__clear__') {
      await provider.setUserName('');
      _showSnackBar('已清除昵称');
    } else if (result != null && result.isNotEmpty) {
      await provider.setUserName(result);
      _showSnackBar('昵称已更新');
    }
  }

  // ==================== 分区标题（原） ====================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryOf(context),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  // ==================== 提醒设置 ====================

  Widget _buildReminderSection() {
    final medCount = context.watch<MoodProvider>().medications.length;

    return _buildCard(
      children: [
        SwitchListTile(
          title: const Text('每日情绪提醒'),
          subtitle: Text(
            _reminderEnabled && _reminderTimes.isNotEmpty
                ? '每天 ${_reminderTimes.length} 个时间点提醒你'
                : '每天定时提醒你记录情绪',
          ),
          value: _reminderEnabled,
          activeThumbColor: AppTheme.primaryColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          onChanged: (value) async {
            await _prefs.setDailyReminderEnabled(value);
            setState(() {
              _reminderEnabled = value;
            });
            if (value) {
              await _notifications.scheduleDailyReminder(_reminderTimes);
              _showSnackBar('已开启每日提醒');
            } else {
              await _notifications.cancelDailyReminders();
              _showSnackBar('已关闭每日提醒');
            }
          },
        ),
        if (_reminderEnabled) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '提醒时间',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._reminderTimes.map((time) => ActionChip(
                      label: Text(time),
                      labelStyle: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                      avatar: const Icon(Icons.schedule, size: 16),
                      onPressed: () => _editReminderTime(time),
                      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )),
                    if (_reminderTimes.length < 10)
                      ActionChip(
                        label: const Text('+ 添加时间'),
                        labelStyle: TextStyle(
                          color: AppTheme.textSecondaryOf(context),
                        ),
                        avatar: const Icon(Icons.add, size: 16),
                        onPressed: _addReminderTime,
                        side: BorderSide(
                          color: AppTheme.dividerOf(context),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildReminderStyleSelector(
            label: '提醒方式',
            value: _dailyReminderStyle,
            showPermissionWarning: _dailyReminderStyle == 'alarm' && !_hasExactAlarmPermission,
            onChanged: (style) async {
              await _prefs.setDailyReminderStyle(style);
              setState(() => _dailyReminderStyle = style);
              if (_reminderEnabled) {
                await _notifications.scheduleDailyReminder(_reminderTimes);
              }
            },
          ),
          _buildDivider(),
        ] else
          _buildDivider(),
        // 用药提醒风格
        _buildReminderStyleSelector(
          label: '用药提醒方式',
          value: _medicationReminderStyle,
          showPermissionWarning: _medicationReminderStyle == 'alarm' && !_hasExactAlarmPermission,
          onChanged: (style) async {
            await _prefs.setMedicationReminderStyle(style);
            setState(() => _medicationReminderStyle = style);
            // 通知 provider 重新调度用药提醒
            final provider = context.read<MoodProvider>();
            await provider.rescheduleMedicationReminders();
          },
        ),
        _buildDivider(),
        _buildActionTile(
          icon: Icons.medication_outlined,
          iconColor: const Color(0xFFEF5350),
          title: '用药提醒',
          subtitle: medCount > 0
              ? '$medCount 种药物 · 点击管理'
              : '添加药物，按时服药提醒',
          isFirst: false,
          isLast: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MedicationReminderPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _addReminderTime() async {
    final lastTime = _reminderTimes.isNotEmpty ? _reminderTimes.last : '20:00';
    final parts = lastTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (_reminderTimes.contains(timeStr)) {
        _showSnackBar('该时间已存在');
        return;
      }
      final newTimes = [..._reminderTimes, timeStr];
      newTimes.sort(); // 按时间排序
      await _prefs.setDailyReminderTimes(newTimes);
      setState(() {
        _reminderTimes = newTimes;
      });
      await _notifications.scheduleDailyReminder(newTimes);
      _showSnackBar('已添加提醒时间 $timeStr');
    }
  }

  Future<void> _editReminderTime(String existingTime) async {
    final parts = existingTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    // 先让用户选择：编辑或删除
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('提醒时间 $existingTime'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            child: const Text('修改时间'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('删除此时间'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (action == 'delete') {
      final newTimes = _reminderTimes.where((t) => t != existingTime).toList();
      if (newTimes.isEmpty) {
        _showSnackBar('至少保留一个提醒时间');
        return;
      }
      await _prefs.setDailyReminderTimes(newTimes);
      setState(() {
        _reminderTimes = newTimes;
      });
      await _notifications.scheduleDailyReminder(newTimes);
      _showSnackBar('已删除提醒时间 $existingTime');
    } else if (action == 'edit') {
      final picked = await showTimePicker(
        context: context,
        initialTime: initial,
      );
      if (picked != null) {
        final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (timeStr != existingTime && _reminderTimes.contains(timeStr)) {
          _showSnackBar('该时间已存在');
          return;
        }
        final newTimes = _reminderTimes.map((t) => t == existingTime ? timeStr : t).toList();
        newTimes.sort();
        await _prefs.setDailyReminderTimes(newTimes);
        setState(() {
          _reminderTimes = newTimes;
        });
        await _notifications.scheduleDailyReminder(newTimes);
      }
    }
  }

  // ==================== 隐私锁 ====================

  Widget _buildPrivacySection() {
    return _buildCard(
      children: [
        SwitchListTile(
          title: const Text('隐私锁'),
          subtitle: const Text('使用 PIN 码保护你的情绪记录'),
          value: _privacyLockEnabled,
          activeThumbColor: AppTheme.primaryColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          onChanged: (value) async {
            if (value) {
              // 开启时需要设置 PIN
              final pin = await _showPinSetupDialog();
              if (pin != null && pin.length == 4) {
                await _prefs.setPinCode(pin);
                await _prefs.setPrivacyLockEnabled(true);
                setState(() {
                  _privacyLockEnabled = true;
                });
                _showSnackBar('隐私锁已开启');
              }
            } else {
              await _prefs.setPrivacyLockEnabled(false);
              setState(() {
                _privacyLockEnabled = false;
              });
              _showSnackBar('隐私锁已关闭');
            }
          },
        ),
        if (_privacyLockEnabled)
          ListTile(
            leading:
                const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
            title: const Text('修改 PIN 码'),
            trailing:
                Icon(Icons.chevron_right, color: AppTheme.textHintOf(context)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            onTap: () => _changePin(),
          ),
      ],
    );
  }

  Future<String?> _showPinSetupDialog() async {
    String pin = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('设置 PIN 码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请输入 4 位数字作为 PIN 码'),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '••••',
                  counterText: '',
                ),
                onChanged: (value) {
                  pin = value;
                },
              ),
            ],
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (pin.length == 4) {
                  Navigator.of(ctx).pop(pin);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入 4 位数字')),
                  );
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePin() async {
    final pin = await _showPinSetupDialog();
    if (pin != null && pin.length == 4) {
      await _prefs.setPinCode(pin);
      _showSnackBar('PIN 码已更新');
    }
  }

  // ==================== 主题设置 ====================

  Widget _buildThemeSection() {
    return _buildCard(
      children: [
        RadioGroup<String>(
          groupValue: _themeMode,
          onChanged: (value) {
            if (value != null) _switchTheme(value);
          },
          child: const Column(
            children: [
              RadioListTile<String>(
                title: Text('浅色模式'),
                value: 'light',
                activeColor: AppTheme.primaryColor,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
              RadioListTile<String>(
                title: Text('深色模式'),
                value: 'dark',
                activeColor: AppTheme.primaryColor,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              RadioListTile<String>(
                title: Text('跟随系统'),
                value: 'system',
                activeColor: AppTheme.primaryColor,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _switchTheme(String mode) async {
    await context.read<MoodProvider>().setThemeMode(mode);
    setState(() {
      _themeMode = mode;
    });
    _showSnackBar(mode == 'dark'
        ? '已切换至深色模式'
        : mode == 'system'
            ? '已切换至跟随系统'
            : '已切换至浅色模式');
  }

  // ==================== 个性化 ====================

  Widget _buildPersonalizationSection() {
    final prefs = PreferencesService();
    return _buildCard(
      children: [
        _buildActionTile(
          icon: Icons.label_outline,
          iconColor: const Color(0xFF26A69A),
          title: '标签管理',
          subtitle: '自定义情绪触发标签',
          isFirst: true,
          isLast: false,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TagManagementPage()),
            );
          },
        ),
        _buildDivider(),
        _buildActionTile(
          icon: Icons.schedule_outlined,
          iconColor: const Color(0xFF5C6BC0),
          title: '时区设置',
          subtitle: _timeZoneDisplayName(prefs.timeZone),
          isFirst: false,
          isLast: true,
          onTap: _showTimeZonePicker,
        ),
      ],
    );
  }

  // ==================== 数据管理 ====================

  Widget _buildDataManagementSection() {
    return _buildCard(
      children: [
        _buildActionTile(
          icon: Icons.table_chart_outlined,
          iconColor: const Color(0xFF4CAF50),
          title: '导出 CSV',
          subtitle: '导出为表格文件',
          isFirst: true,
          onTap: _exportCsv,
        ),
        _buildDivider(),
        _buildActionTile(
          icon: Icons.picture_as_pdf_outlined,
          iconColor: const Color(0xFFE53935),
          title: '导出 PDF',
          subtitle: '导出为 PDF 报告',
          onTap: _exportPdf,
        ),
        _buildDivider(),
        _buildActionTile(
          icon: Icons.backup_outlined,
          iconColor: const Color(0xFF2196F3),
          title: '数据备份',
          subtitle: '备份所有数据为 JSON',
          onTap: _backupData,
        ),
        _buildDivider(),
        _buildActionTile(
          icon: Icons.restore,
          iconColor: const Color(0xFFFF9800),
          title: '数据恢复',
          subtitle: '从备份文件恢复数据',
          isLast: true,
          onTap: _restoreData,
        ),
      ],
    );
  }

  // ==================== 更多 ====================

  Widget _buildMoreSection() {
    return _buildCard(
      children: [
        _buildActionTile(
          icon: Icons.favorite_border,
          iconColor: const Color(0xFFE8B4B8),
          title: '危机支持',
          subtitle: '心理援助热线 · 你并不孤单',
          isFirst: true,
          isLast: false,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CrisisSupportPage()),
            );
          },
        ),
        _buildActionTile(
          icon: Icons.self_improvement_outlined,
          iconColor: const Color(0xFF64B5F6),
          title: '情绪安全记录',
          subtitle: '觉察冲动与应对 · 温柔照顾自己',
          isFirst: false,
          isLast: false,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UrgeLogPage()),
            );
          },
        ),
        _buildActionTile(
          icon: Icons.psychology_outlined,
          iconColor: const Color(0xFF7E57C2),
          title: '心理测评',
          subtitle: 'PHQ-9、GAD-7 等专业量表',
          isFirst: false,
          isLast: false,
          onTap: () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AssessmentWebPage()));
          },
        ),
        _buildActionTile(
          icon: Icons.cottage_outlined,
          iconColor: const Color(0xFF66BB6A),
          title: '栖息所',
          subtitle: '安静的角落 · 让心歇一歇',
          isFirst: false,
          isLast: false,
          onTap: () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QisoulWebPage()));
          },
        ),
        _buildActionTile(
          icon: Icons.volunteer_activism_outlined,
          iconColor: const Color(0xFF9575CD),
          title: '暖心寄语',
          subtitle: '致每一个正在努力的你',
          isFirst: false,
          isLast: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WarmWordsPage()),
            );
          },
        ),
      ],
    );
  }

  // ==================== 关于 ====================

  Widget _buildAboutSection() {
    return _buildCard(
      children: [
        _buildActionTile(
          icon: Icons.info_outline,
          iconColor: AppTheme.primaryColor,
          title: '关于软件',
          subtitle: '版本信息 · 更新日志 · 开源许可',
          isFirst: true,
          isLast: false,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SoftwareInfoPage(),
              ),
            );
          },
        ),
        _buildDivider(),
        _buildActionTile(
          icon: Icons.person_outline,
          iconColor: const Color(0xFF8BE9C1),
          title: '关于作者',
          subtitle: '了解脑电波背后的故事',
          isFirst: false,
          isLast: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AboutPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ==================== 通用组件 ====================

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBgOf(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isFirst ? 16 : 0),
      topRight: Radius.circular(isFirst ? 16 : 0),
      bottomLeft: Radius.circular(isLast ? 16 : 0),
      bottomRight: Radius.circular(isLast ? 16 : 0),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textHintOf(context),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: AppTheme.textHintOf(context), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: AppTheme.dividerOf(context)),
    );
  }

  Widget _buildReminderStyleSelector({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool showPermissionWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                selectedForegroundColor: AppTheme.primaryColor,
              ),
              segments: const [
                ButtonSegment(value: 'notification', label: Text('系统通知')),
                ButtonSegment(value: 'alarm', label: Text('闹钟')),
              ],
              selected: {value},
              onSelectionChanged: (newVal) => onChanged(newVal.first),
            ),
          ),
          if (showPermissionWarning) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: Colors.orange.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '精确闹钟权限未开启，通知将以普通模式送达',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==================== 数据操作 ====================

  Future<void> _exportCsv() async {
    try {
      final provider = context.read<MoodProvider>();
      final records = provider.allRecords;
      if (records.isEmpty) {
        _showSnackBar('暂无数据可导出');
        return;
      }

      final buffer = StringBuffer();
      buffer.write('\uFEFF');
      buffer.writeln('日期,时间,情绪,强度,备注,标签,日记,日记图片');

      for (final r in records) {
        final date =
            '${r.createdAt.year}-${r.createdAt.month.toString().padLeft(2, '0')}-${r.createdAt.day.toString().padLeft(2, '0')}';
        final time =
            '${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
        final mood = r.moodType.label;
        final intensity = r.intensity.toString();
        final note = _escapeCsv(r.note ?? '');
        final tags = _escapeCsv(r.tags.join(';'));
        final diary = _escapeCsv(r.diary ?? '');
        final diaryImages = _escapeCsv(r.diaryImages.join(';'));
        buffer.writeln('$date,$time,$mood,$intensity,$note,$tags,$diary,$diaryImages');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mood_tab_export.csv');
      await file.writeAsString(buffer.toString(), encoding: const Utf8Codec());

      await Share.shareXFiles([XFile(file.path)], text: '脑电波 情绪记录导出');
    } catch (e) {
      _showSnackBar('导出失败：$e');
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _exportPdf() async {
    try {
      final provider = context.read<MoodProvider>();
      final records = provider.allRecords;
      if (records.isEmpty) {
        _showSnackBar('暂无数据可导出');
        return;
      }

      _showSnackBar('正在生成报告...');

      final pdf = pw.Document();

      // 尝试多种方式加载中文字体
      pw.Font? font;
      final fontData = await _loadCjkFont();
      if (fontData != null) {
        font = pw.Font.ttf(fontData);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  '脑电波 情绪记录报告',
                  style: font != null
                      ? pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold)
                      : const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              if (provider.userName.isNotEmpty)
                pw.Text('用户：${provider.userName}', style: font != null ? pw.TextStyle(font: font) : null),
              pw.Text('导出时间：${DateTime.now().toString().substring(0, 19)}', style: font != null ? pw.TextStyle(font: font) : null),
              pw.Text('记录总数：${records.length} 条', style: font != null ? pw.TextStyle(font: font) : null),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['日期', '时间', '情绪', '强度', '备注'],
                data: records.map((r) {
                  return [
                    '${r.createdAt.month}/${r.createdAt.day}',
                    '${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}',
                    r.moodType.label,
                    r.intensity.toString(),
                    r.note ?? '',
                  ];
                }).toList(),
                headerStyle: font != null
                    ? pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)
                    : const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: font != null ? pw.TextStyle(font: font) : null,
              ),
            ];
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mood_tab_report.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: '脑电波 情绪记录报告');
    } catch (e) {
      _showSnackBar('导出失败：$e');
    }
  }


  Future<ByteData?> _loadCjkFont() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${dir.path}/cjk_font.ttf');

      if (await cacheFile.exists()) {
        return await cacheFile.readAsBytes().then((b) => b.buffer.asByteData());
      }

      final urls = [
        'https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400',
      ];

      for (final cssUrl in urls) {
        final cssResponse = await http.get(Uri.parse(cssUrl));
        if (cssResponse.statusCode == 200) {
          final cssContent = cssResponse.body;
          final ttfUrlMatch = RegExp(r'url\(([^)]+)\)').firstMatch(cssContent);
          if (ttfUrlMatch != null) {
            var ttfUrl = ttfUrlMatch.group(1)!;
            if (ttfUrl.startsWith('//')) {
              ttfUrl = 'https:$ttfUrl';
            }
            final ttfResponse = await http.get(Uri.parse(ttfUrl));
            if (ttfResponse.statusCode == 200) {
              await cacheFile.writeAsBytes(ttfResponse.bodyBytes);
              return ttfResponse.bodyBytes.buffer.asByteData();
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _backupData() async {
    try {
      final data = await _dbService.exportAll();
      if (data.isEmpty) {
        _showSnackBar('暂无数据可备份');
        return;
      }

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/mood_tab_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles([XFile(file.path)], text: '脑电波 数据备份');
    } catch (e) {
      _showSnackBar('备份失败：$e');
    }
  }

  Future<void> _restoreData() async {
    _showSnackBar('请通过文件管理器选择备份文件恢复');
  }

  // ==================== 工具 ====================

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ==================== 时区选择 ====================

  /// 常用时区列表
  static const _timeZones = [
    {'name': 'Asia/Shanghai', 'label': '中国标准时间 (UTC+8)'},
    {'name': 'Asia/Hong_Kong', 'label': '香港时间 (UTC+8)'},
    {'name': 'Asia/Taipei', 'label': '台北时间 (UTC+8)'},
    {'name': 'Asia/Tokyo', 'label': '日本标准时间 (UTC+9)'},
    {'name': 'Asia/Seoul', 'label': '韩国标准时间 (UTC+9)'},
    {'name': 'Asia/Singapore', 'label': '新加坡时间 (UTC+8)'},
    {'name': 'Asia/Bangkok', 'label': '泰国时间 (UTC+7)'},
    {'name': 'Asia/Kolkata', 'label': '印度时间 (UTC+5:30)'},
    {'name': 'Asia/Dubai', 'label': '海湾标准时间 (UTC+4)'},
    {'name': 'Europe/London', 'label': '英国时间 (UTC+0/+1)'},
    {'name': 'Europe/Paris', 'label': '中欧时间 (UTC+1/+2)'},
    {'name': 'Europe/Moscow', 'label': '莫斯科时间 (UTC+3)'},
    {'name': 'America/New_York', 'label': '美东时间 (UTC-5/-4)'},
    {'name': 'America/Chicago', 'label': '美中时间 (UTC-6/-5)'},
    {'name': 'America/Denver', 'label': '美山时间 (UTC-7/-6)'},
    {'name': 'America/Los_Angeles', 'label': '美西时间 (UTC-8/-7)'},
    {'name': 'America/Toronto', 'label': '加拿大多伦多 (UTC-5/-4)'},
    {'name': 'America/Sao_Paulo', 'label': '巴西圣保罗 (UTC-3)'},
    {'name': 'Australia/Sydney', 'label': '澳洲悉尼 (UTC+10/+11)'},
    {'name': 'Pacific/Auckland', 'label': '新西兰 (UTC+12/+13)'},
  ];

  String _timeZoneDisplayName(String tzName) {
    for (final tz in _timeZones) {
      if (tz['name'] == tzName) return tz['label']!;
    }
    return tzName;
  }

  Future<void> _showTimeZonePicker() async {
    final prefs = PreferencesService();
    final current = prefs.timeZone;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String tempSelection = current;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('选择时区'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _timeZones.length,
                  itemBuilder: (ctx, index) {
                    final tz = _timeZones[index];
                    final isSelected = tz['name'] == tempSelection;
                    return RadioListTile<String>(
                      value: tz['name']!,
                      groupValue: tempSelection,
                      title: Text(tz['label']!),
                      dense: true,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => tempSelection = value);
                        }
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(tempSelection),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null && selected != current) {
      await prefs.setTimeZone(selected);
      // 刷新通知服务的时区
      final notifications = NotificationService();
      await notifications.refreshTimeZone();
      // 重新调度每日提醒
      if (prefs.dailyReminderEnabled && prefs.dailyReminderTimes.isNotEmpty) {
        await notifications.scheduleDailyReminder(prefs.dailyReminderTimes);
      }
      // 重新调度药物提醒
      if (context.mounted) {
        final provider = context.read<MoodProvider>();
        await provider.rescheduleMedicationReminders();
      }
      setState(() {});
      _showSnackBar('时区已更改为 ${_timeZoneDisplayName(selected)}');
    }
  }
}
