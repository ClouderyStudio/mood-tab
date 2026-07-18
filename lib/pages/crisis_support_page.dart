import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// 显示关怀提示，并从仍然存活的导航器进入热线页面。
Future<void> showCrisisSupportDialog(BuildContext context) {
  final navigator = Navigator.of(context);

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Text('🌿', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '我想关心你一下',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: const Text(
          '你记录的情绪比较强烈，如果你正在经历很大的痛苦，'
          '或者有伤害自己的念头，请一定知道——你并不孤单，'
          '有人愿意倾听和帮助你。\n\n'
          '可以拨打心理援助热线，专业的接线员会陪伴你。',
          style: TextStyle(fontSize: 15, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => const CrisisSupportPage(),
                ),
              );
            },
            child: const Text(
              '查看热线',
              style: TextStyle(
                color: Color(0xFFE8B4B8),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '我没事，谢谢',
              style: TextStyle(
                color: AppTheme.textSecondaryOf(context),
                fontSize: 16,
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// 危机支持页面
/// 提供全国心理援助热线信息
/// 当用户感到极度痛苦或有自伤念头时，提供及时的帮助渠道
class CrisisSupportPage extends StatelessWidget {
  const CrisisSupportPage({super.key});

  static const List<_HotlineInfo> _hotlines = [
    _HotlineInfo(
      name: '全国统一心理援助热线',
      number: '12356',
      description: '国家卫健委设立，24 小时公益免费，全国通用',
      available: '24 小时',
    ),
    _HotlineInfo(
      name: '全国心理危机干预热线',
      number: '400-161-9995',
      description: '24 小时心理危机干预与自杀预防',
      available: '24 小时',
    ),
    _HotlineInfo(
      name: '全国青少年心理咨询热线',
      number: '12355',
      description: '面向青少年的心理咨询与援助',
      available: '24 小时',
    ),
    _HotlineInfo(
      name: '北京心理危机研究与干预中心',
      number: '010-82951332',
      description: '北京回龙观医院，24 小时危机干预',
      available: '24 小时',
    ),
    _HotlineInfo(
      name: '教育部心理援助热线',
      number: '4009678920',
      description: '华中师范大学心理援助，8:00-24:00',
      available: '8:00-24:00',
    ),
    _HotlineInfo(
      name: '希望24热线',
      number: '400-161-9995',
      description: '生命教育与危机干预，24 小时',
      available: '24 小时',
    ),
  ];

  Future<void> _callPhone(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('危机支持'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 关怀信息卡片
              _buildCareCard(context),
              const SizedBox(height: 24),

              // 热线列表
              Text(
                '心理援助热线',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '以下热线均为公益免费，24 小时有人接听',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
              const SizedBox(height: 16),
              ..._hotlines.map((h) => _buildHotlineCard(context, h)),
              const SizedBox(height: 24),

              // 温馨提示
              _buildTipsCard(context),
              const SizedBox(height: 20),

              // 免责声明
              Text(
                '本页面提供的热线信息仅供参考，如有紧急情况请直接拨打 120 或前往最近的医院急诊。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textHintOf(context),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCareCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8B4B8), Color(0xFFD4A5A5)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🌿',
            style: TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          Text(
            '你并不孤单',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            '如果你正在经历极度的痛苦，或者有伤害自己的念头，请一定要寻求帮助。\n\n这些感受是真实的，但它们不会永远持续。有人愿意倾听你、陪伴你度过这个艰难的时刻。',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotlineCard(BuildContext context, _HotlineInfo info) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBgOf(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8B4B8).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1B3A1B)
                            : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        info.available,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _callPhone(info.number),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B4B8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.phone, color: Colors.white, size: 20),
                  const SizedBox(height: 2),
                  Text(
                    info.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D3520) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF5C4E2A) : const Color(0xFFFFE082),
            width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                '当你感到难以承受时',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            '试着深呼吸：慢慢吸气 4 秒，屏住 4 秒，缓缓呼出 6 秒',
            '联系你信任的人，哪怕只是说一句「我现在不太好」',
            '远离可能伤害到自己的物品',
            '去人多的地方，哪怕只是坐在公园里',
            '拨打上面的热线，专业的接线员会陪伴你',
          ].map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('·',
                        style:
                            TextStyle(fontSize: 16, color: Color(0xFFFF9800))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimaryOf(context),
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _HotlineInfo {
  final String name;
  final String number;
  final String description;
  final String available;

  const _HotlineInfo({
    required this.name,
    required this.number,
    required this.description,
    required this.available,
  });
}
