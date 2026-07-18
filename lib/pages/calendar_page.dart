import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mood_record.dart';
import '../models/mood_type.dart';
import '../providers/mood_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/intensity_dots.dart';
import 'mood_record_page.dart';

/// 日历视图页面
/// 月历展示每日情绪颜色，点击某天查看当天所有记录
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  List<MoodRecord> _selectedDayRecords = [];
  Map<String, List<MoodRecord>> _monthRecords = {};
  bool _isLoading = false;
  MoodProvider? _providerRef;

  @override
  void initState() {
    super.initState();
    // 自动选中今天，使首次打开日历时直接显示当天记录
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _providerRef = context.read<MoodProvider>();
      _providerRef!.addListener(_onProviderChanged);
      _loadMonthData();
    });
  }

  @override
  void dispose() {
    _providerRef?.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() {
      _isLoading = true;
    });

    final provider = context.read<MoodProvider>();
    final start = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final end =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0, 23, 59, 59);
    final records = await provider.getRecordsBetween(start, end);

    final grouped = <String, List<MoodRecord>>{};
    for (final r in records) {
      final key = '${r.createdAt.year}-${r.createdAt.month}-${r.createdAt.day}';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    setState(() {
      _monthRecords = grouped;
      _isLoading = false;
    });

    if (_selectedDate != null) {
      _loadSelectedDay(_selectedDate!);
    }
  }

  void _loadSelectedDay(DateTime date) {
    final key = '${date.year}-${date.month}-${date.day}';
    setState(() {
      _selectedDate = date;
      _selectedDayRecords = _monthRecords[key] ?? [];
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
      _selectedDate = null;
      _selectedDayRecords = [];
    });
    _loadMonthData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildWeekdayLabels(),
            _isLoading
                ? const Expanded(
                    child: Center(child: CircularProgressIndicator()))
                : _buildCalendarGrid(),
            if (_selectedDate != null) _buildSelectedDayDetail(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final monthNames = [
      '一月',
      '二月',
      '三月',
      '四月',
      '五月',
      '六月',
      '七月',
      '八月',
      '九月',
      '十月',
      '十一月',
      '十二月'
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text(
            '${_focusedMonth.year}年 ${monthNames[_focusedMonth.month - 1]}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left, size: 28),
            color: AppTheme.textSecondaryOf(context),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right, size: 28),
            color: AppTheme.textSecondaryOf(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    final labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: labels.map((label) {
          return Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textHintOf(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    // 周一=1, 周日=7 → 转为索引 0-6
    final firstWeekday = (firstOfMonth.weekday - 1);

    final today = DateTime.now();
    final isCurrentMonth =
        today.year == _focusedMonth.year && today.month == _focusedMonth.month;

    return Expanded(
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -300) {
            _changeMonth(1); // 左滑 → 下个月
          } else if (details.primaryVelocity! > 300) {
            _changeMonth(-1); // 右滑 → 上个月
          }
        },
        child: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.85,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: firstWeekday + daysInMonth,
          itemBuilder: (context, index) {
          if (index < firstWeekday) {
            return const SizedBox.shrink();
          }
          final day = index - firstWeekday + 1;
          final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
          final key = '${date.year}-${date.month}-${date.day}';
          final dayRecords = _monthRecords[key] ?? [];
          final isToday = isCurrentMonth && day == today.day;
          final isSelected = _selectedDate?.day == day &&
              _selectedDate?.month == _focusedMonth.month &&
              _selectedDate?.year == _focusedMonth.year;

          return _buildDayCell(
            date: date,
            day: day,
            records: dayRecords,
            isToday: isToday,
            isSelected: isSelected,
            onTap: () => _loadSelectedDay(date),
          );
        },
        ),
      ),
    );
  }

  Widget _buildDayCell({
    required DateTime date,
    required int day,
    required List<MoodRecord> records,
    required bool isToday,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final hasRecords = records.isNotEmpty;

    // 如果有记录，取最主要情绪的颜色
    Color? moodColor;
    if (hasRecords) {
      final counts = <MoodType, int>{};
      for (final r in records) {
        counts[r.moodType] = (counts[r.moodType] ?? 0) + 1;
      }
      final topMood =
          counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      moodColor = Color(topMood.key.colorValue);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : (moodColor != null
                  ? moodColor.withValues(alpha: 0.12)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(color: AppTheme.primaryColor, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                color: isToday
                    ? AppTheme.primaryColor
                    : (hasRecords
                        ? AppTheme.textPrimaryOf(context)
                        : AppTheme.textHintOf(context)),
              ),
            ),
            const SizedBox(height: 2),
            if (hasRecords) ...[
              // 情绪圆点指示
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: records.take(3).map((r) {
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(r.moodType.colorValue),
                    ),
                  );
                }).toList(),
              ),
              if (records.length > 3)
                Text(
                  '${records.length}',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.textHintOf(context),
                  ),
                ),
            ] else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayDetail() {
    if (_selectedDayRecords.isEmpty) {
      // 无记录 — 显示补记按钮
      final now = DateTime.now();
      final isFuture = _selectedDate!.isAfter(DateTime(now.year, now.month, now.day));

      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isFuture ? '未来的日期还没到来' : '这天没有记录',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textHintOf(context),
                  ),
            ),
            if (!isFuture) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MoodRecordPage(initialDate: _selectedDate!),
                    ),
                  );
                  if (result == true) {
                    _loadMonthData();
                  }
                },
                icon: const Icon(Icons.event_note, size: 16),
                label: const Text('补记这天的心情'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedDate!.month}月${_selectedDate!.day}日 · ${_selectedDayRecords.length} 条记录',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // 继续补记按钮
                TextButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MoodRecordPage(initialDate: _selectedDate!),
                      ),
                    );
                    if (result == true) {
                      _loadMonthData();
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('追加'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    textStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              itemCount: _selectedDayRecords.length,
              itemBuilder: (context, index) {
                final record = _selectedDayRecords[index];
                return _buildDayRecordCard(record);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRecordCard(MoodRecord record) {
    final moodColor = Color(record.moodType.colorValue);
    final hour = record.createdAt.hour.toString().padLeft(2, '0');
    final minute = record.createdAt.minute.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBgOf(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: moodColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(record.moodType.emoji,
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record.moodType.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    IntensityDots(
                        intensity: record.intensity, color: moodColor, size: 6),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$hour:$minute',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textHintOf(context),
                      ),
                ),
                if (record.note != null && record.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.note!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
