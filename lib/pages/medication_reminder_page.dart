import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medication.dart';
import '../providers/mood_provider.dart';
import '../theme/app_theme.dart';

/// 用药提醒页面
/// 管理药物列表：添加、编辑、删除、启用/禁用提醒
class MedicationReminderPage extends StatefulWidget {
  const MedicationReminderPage({super.key});

  @override
  State<MedicationReminderPage> createState() =>
      _MedicationReminderPageState();
}

class _MedicationReminderPageState extends State<MedicationReminderPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用药提醒'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showEditDialog(context),
            tooltip: '添加药物',
          ),
        ],
      ),
      body: Consumer<MoodProvider>(
        builder: (context, provider, _) {
          final medications = provider.medications;

          if (medications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💊', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text(
                    '还没有添加药物',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右上角添加药物提醒',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryOf(context),
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showEditDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('添加药物'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: medications.length,
            itemBuilder: (context, index) {
              return _buildMedicationCard(medications[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMedicationCard(Medication med) {
    final timeStr = med.times.map((t) => t).join('  ·  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBgOf(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 主体内容
          InkWell(
            onTap: () => _showEditDialog(context, medication: med),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 药物图标
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (med.enabled
                              ? AppTheme.primaryColor
                              : AppTheme.textHintOf(context))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '💊',
                        style: TextStyle(
                          fontSize: 24,
                          color: med.enabled
                              ? null
                              : AppTheme.textHintOf(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 药物信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                med.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      decoration: med.enabled
                                          ? null
                                          : TextDecoration.lineThrough,
                                      color: med.enabled
                                          ? null
                                          : AppTheme.textHintOf(context),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                med.dosage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                timeStr,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryOf(context),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (med.notes != null && med.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            med.notes!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppTheme.textHintOf(context),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 底部操作栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // 启用/禁用开关
                Text(
                  med.enabled ? '已启用' : '已暂停',
                  style: TextStyle(
                    fontSize: 12,
                    color: med.enabled
                        ? AppTheme.primaryColor
                        : AppTheme.textHintOf(context),
                  ),
                ),
                const Spacer(),
                Switch(
                  value: med.enabled,
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    context
                        .read<MoodProvider>()
                        .toggleMedicationEnabled(med.id);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red.shade400,
                  onPressed: () => _confirmDelete(med),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 添加/编辑药物弹窗
  void _showEditDialog(BuildContext context, {Medication? medication}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MedicationEditSheet(medication: medication),
    );
  }

  /// 确认删除
  void _confirmDelete(Medication med) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除药物'),
        content: Text('确定要删除「${med.name}」的提醒吗？'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              context.read<MoodProvider>().deleteMedication(med.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已删除「${med.name}」'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 添加/编辑药物的底部弹窗
class _MedicationEditSheet extends StatefulWidget {
  final Medication? medication;

  const _MedicationEditSheet({this.medication});

  @override
  State<_MedicationEditSheet> createState() => _MedicationEditSheetState();
}

class _MedicationEditSheetState extends State<_MedicationEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _notesCtrl;
  List<TimeOfDay> _times = [];

  bool get isEditing => widget.medication != null;

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    _nameCtrl = TextEditingController(text: med?.name ?? '');
    _dosageCtrl = TextEditingController(text: med?.dosage ?? '1片');
    _notesCtrl = TextEditingController(text: med?.notes ?? '');
    if (med != null) {
      _times = med.times.map((t) {
        final parts = t.split(':');
        return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }).toList();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽指示器
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textHintOf(context).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 标题
              Text(
                isEditing ? '编辑药物' : '添加药物',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              // 药物名称
              TextField(
                controller: _nameCtrl,
                autofocus: !isEditing,
                decoration: const InputDecoration(
                  labelText: '药物名称',
                  hintText: '如：舍曲林、维生素D',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication_outlined),
                ),
              ),
              const SizedBox(height: 16),
              // 剂量
              TextField(
                controller: _dosageCtrl,
                decoration: const InputDecoration(
                  labelText: '剂量',
                  hintText: '如：1片、5ml、2粒',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
              ),
              const SizedBox(height: 16),
              // 提醒时间
              Text(
                '提醒时间',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._times.asMap().entries.map((entry) {
                    final i = entry.key;
                    final t = entry.value;
                    return Chip(
                      label: Text(
                        '${t.hour.toString().padLeft(2, '0')}:'
                        '${t.minute.toString().padLeft(2, '0')}',
                      ),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _times.removeAt(i);
                        });
                      },
                    );
                  }),
                  if (_times.length < Medication.maxTimes)
                    ActionChip(
                      label: const Text('+ 添加时间'),
                      avatar: const Icon(Icons.add, size: 18),
                      onPressed: _pickTime,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // 备注
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '如：饭后服用',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_outlined),
                ),
              ),
              const SizedBox(height: 24),
              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(isEditing ? '保存' : '添加'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _times.add(picked);
      });
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final dosage = _dosageCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    if (name.isEmpty) {
      _showToast('请输入药物名称');
      return;
    }
    if (dosage.isEmpty) {
      _showToast('请输入剂量');
      return;
    }
    if (_times.isEmpty) {
      _showToast('请至少添加一个提醒时间');
      return;
    }

    final timeStrings = _times
        .map((t) =>
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .toList();

    final provider = context.read<MoodProvider>();

    // 药物数量上限检查
    if (!isEditing && provider.medications.length >= Medication.maxMedications) {
      _showToast('最多只能添加 ${Medication.maxMedications} 种药物');
      return;
    }

    if (isEditing) {
      final updated = widget.medication!.copyWith(
        name: name,
        dosage: dosage,
        times: timeStrings,
        notes: notes,
      );
      provider.updateMedication(updated);
      _showToast('已更新「$name」');
    } else {
      final med = Medication(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        dosage: dosage,
        times: timeStrings,
        notes: notes,
      );
      provider.addMedication(med);
      _showToast('已添加「$name」');
    }

    Navigator.of(context).pop();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
