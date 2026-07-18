/// 药物提醒模型
/// 记录药物名称、剂量、提醒时间列表等信息
class Medication {
  /// 唯一标识（时间戳生成的 int）
  final int id;

  /// 药物名称
  final String name;

  /// 剂量描述，如 "1片"、"5ml"
  final String dosage;

  /// 提醒时间列表，格式 "HH:mm"，如 ["08:00", "20:00"]
  final List<String> times;

  /// 备注（可选）
  final String? notes;

  /// 是否启用提醒
  final bool enabled;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.times,
    this.notes,
    this.enabled = true,
  });

  /// 生成通知 ID：基于药物在列表中的索引，避免 id 过大溢出 Android 32-bit int
  /// 格式：200 + medIndex * 10 + timeIndex
  /// 支持最多 80 种药物 × 10 个时间点（ID 范围 200~999）
  static const int _medIdBase = 200;
  static const int maxMedications = 80;

  int notificationIdFor(int medIndex, int timeIndex) =>
      _medIdBase + medIndex * 10 + timeIndex;

  /// 最大时间点数
  static const int maxTimes = 10;

  Medication copyWith({
    String? name,
    String? dosage,
    List<String>? times,
    String? notes,
    bool? enabled,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      times: times ?? this.times,
      notes: notes ?? this.notes,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'times': times,
        'notes': notes,
        'enabled': enabled,
      };

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as int,
      name: json['name'] as String,
      dosage: json['dosage'] as String,
      times: (json['times'] as List).cast<String>(),
      notes: json['notes'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
