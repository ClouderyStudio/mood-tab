import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../models/mood_record.dart';
import '../models/mood_type.dart';
import '../providers/mood_provider.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class MoodGardenPage extends StatefulWidget {
  const MoodGardenPage({super.key});

  @override
  State<MoodGardenPage> createState() => _MoodGardenPageState();
}

enum BrushType {
  pen,
  eraser,
}

class Stroke {
  final List<Offset> points;
  final Color color;
  final double size;
  final BrushType brushType;

  Stroke({
    required this.points,
    required this.color,
    required this.size,
    required this.brushType,
  });

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
    'color': color.toARGB32(),
    'size': size,
    'brushType': brushType.name,
  };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
    points: (json['points'] as List)
        .map((p) => Offset(
              (p['dx'] as num).toDouble(),
              (p['dy'] as num).toDouble(),
            ))
        .toList(),
    color: Color(json['color'] as int),
    size: (json['size'] as num).toDouble(),
    brushType: BrushType.values.firstWhere(
      (b) => b.name == json['brushType'],
      orElse: () => BrushType.pen,
    ),
  );
}

class _MoodGardenPageState extends State<MoodGardenPage> {
  List<MoodRecord> _recentRecords = [];
  bool _isLoading = false;
  MoodProvider? _providerRef;

  BrushType _brushType = BrushType.pen;
  Color _brushColor = Colors.pink;
  double _brushSize = 4.0;
  double _eraserSize = 12.0;
  List<Stroke> _strokes = [];
  List<Stroke> _redoneStrokes = [];
  // 当前正在绘制的笔迹用 ValueNotifier 承载：指针移动只让涂鸦层
  // CustomPaint 重绘，不触发整页 setState（避免 Consumer/工具栏/列表重建）。
  final ValueNotifier<List<Offset>> _currentPoints = ValueNotifier([]);
  Timer? _saveDebounce;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _providerRef = context.read<MoodProvider>();
      _providerRef!.addListener(_onProviderChanged);
      _loadData();
      _loadDoodles();
    });
  }

  @override
  void dispose() {
    _providerRef?.removeListener(_onProviderChanged);
    // 若有未落盘的防抖保存，离开前立即冲刷，避免丢失最后一笔
    if (_saveDebounce?.isActive ?? false) {
      _flushSaveDoodles();
    }
    _currentPoints.dispose();
    super.dispose();
  }

  void _startDrawing(Offset point) {
    // 新一笔开始：清空重做栈（需要刷新撤销/重做按钮状态）
    if (_redoneStrokes.isNotEmpty) {
      setState(() => _redoneStrokes = []);
    }
    _currentPoints.value = [point];
  }

  void _draw(Offset point) {
    // 仅更新 notifier，涂鸦层 CustomPaint 通过 repaint 监听独立重绘，
    // 不重建整页。新建列表以触发 ValueNotifier 的引用变化通知。
    _currentPoints.value = [..._currentPoints.value, point];
  }

  void _endDrawing() {
    _commitCurrentStroke();
  }

  /// 提交当前正在画的笔迹（用于颜色/粗细切换时分段，保持旧色不变）
  ///
  /// 注意：每次都重新赋值为新 list，而非原地 add/removeLast。因为画笔的
  /// shouldRepaint 依赖新旧 list 的引用差异来判断是否重绘，原地修改会让
  /// 新旧 delegate 指向同一 list，导致撤销/重做不刷新。
  void _commitCurrentStroke() {
    final points = _currentPoints.value;
    if (points.isNotEmpty) {
      setState(() {
        _strokes = [
          ..._strokes,
          Stroke(
            points: List.from(points),
            color: _brushColor,
            size: _activeSize,
            brushType: _brushType,
          ),
        ];
        _redoneStrokes = [];
      });
      _currentPoints.value = [];
      _saveDoodles();
    }
  }

  void _clearDrawing() {
    setState(() {
      _strokes = [];
      _redoneStrokes = [];
    });
    _currentPoints.value = [];
    _saveDoodles();
  }

  void _undoDrawing() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _redoneStrokes = [..._redoneStrokes, _strokes.last];
        _strokes = _strokes.sublist(0, _strokes.length - 1);
      });
      _saveDoodles();
    }
  }

  void _redoDrawing() {
    if (_redoneStrokes.isNotEmpty) {
      setState(() {
        _strokes = [..._strokes, _redoneStrokes.last];
        _redoneStrokes = _redoneStrokes.sublist(0, _redoneStrokes.length - 1);
      });
      _saveDoodles();
    }
  }

  void _toggleEraser() {
    _commitCurrentStroke();
    setState(() {
      _brushType = _brushType == BrushType.pen ? BrushType.eraser : BrushType.pen;
    });
    PreferencesService().setEraserSize(_eraserSize);
  }

  double get _activeSize =>
      _brushType == BrushType.eraser ? _eraserSize : _brushSize;

  void _onProviderChanged() {
    _loadData();
  }

  void _loadDoodles() {
    try {
      final json = jsonDecode(PreferencesService().gardenDoodles) as List;
      final loaded = json
          .map((e) => Stroke.fromJson(e as Map<String, dynamic>))
          .toList();
      // 同时恢复橡皮擦大小
      final savedEraserSize = PreferencesService().eraserSize;
      setState(() {
        _strokes = loaded;
        _eraserSize = savedEraserSize;
      });
    } catch (_) {}
  }

  /// 保存涂鸦。防抖 400ms，避免连续操作时频繁 jsonEncode 阻塞主线程。
  void _saveDoodles() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _flushSaveDoodles);
  }

  /// 立即持久化涂鸦（用于离开页面时冲刷未落盘的防抖保存）。
  void _flushSaveDoodles() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    final json = jsonEncode(_strokes.map((s) => s.toJson()).toList());
    PreferencesService().setGardenDoodles(json);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = context.read<MoodProvider>();
    _recentRecords = await provider.getRecentRecords(30);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('情绪花园'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Consumer<MoodProvider>(
          builder: (context, provider, _) {
            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_recentRecords.isEmpty) {
              return const EmptyState(
                emoji: '🌱',
                title: '花园还是一片空地',
                subtitle: '记录情绪后，这里会开出属于你的花',
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '情绪花园',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '你的每一段心情，都是一朵花',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                      ),
                      const SizedBox(height: 24),
                      _buildGardenStats(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                _buildGardenCanvas(Theme.of(context).brightness == Brightness.dark),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildDrawingToolbar(),
                      const SizedBox(height: 24),
                      _buildFlowerLegend(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGardenStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bloomingCount = _recentRecords.where((r) {
      final diff = today.difference(DateTime(
        r.createdAt.year,
        r.createdAt.month,
        r.createdAt.day,
      ));
      return diff.inDays < 7;
    }).length;
    final wiltingCount = _recentRecords.length - bloomingCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildStatItem('🌸', '$bloomingCount', '绽放中'),
          const SizedBox(width: 24),
          _buildStatItem('🥀', '$wiltingCount', '已凋零'),
          const SizedBox(width: 24),
          _buildStatItem('🌱', '${_recentRecords.length}', '总花朵'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryOf(context),
              ),
        ),
      ],
    );
  }

  Widget _buildGardenCanvas(bool isDark) {
    return Container(
      key: _canvasKey,
      height: 380,
      decoration: BoxDecoration(
        color: AppTheme.cardBgOf(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: const Size(double.infinity, double.infinity),
                painter: _GardenPainter(
                  records: _recentRecords,
                  isDark: isDark,
                ),
              ),
            ),
            _buildButterflyAnimation(),
            _buildStarAnimation(isDark),
            _buildDrawingLayer(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawingLayer(bool isDark) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _startDrawing(event.localPosition);
      },
      onPointerMove: (event) {
        _draw(event.localPosition);
      },
      onPointerUp: (_) {
        _endDrawing();
      },
      onPointerCancel: (_) {
        _endDrawing();
      },
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size(double.infinity, double.infinity),
          painter: _DrawingPainter(
            strokes: _strokes,
            currentPoints: _currentPoints,
            currentColor: _brushColor,
            currentSize: _activeSize,
            currentBrushType: _brushType,
          ),
          // 提交后的笔迹层：仅在 strokes/画笔属性变化（setState）时重建
        ),
      ),
    );
  }

  Widget _buildButterflyAnimation() {
    if (_recentRecords.length < 5) return const SizedBox.shrink();
    return const _ButterflyAnimation();
  }

  Widget _buildStarAnimation(bool isDark) {
    if (!isDark || _recentRecords.isEmpty) return const SizedBox.shrink();
    return const _StarAnimation();
  }

  Widget _buildFlowerLegend() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBgOf(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '花语解读',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: MoodType.values.map((mood) {
              return _buildLegendItem(mood);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(MoodType mood) {
    final color = Color(mood.colorValue);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${mood.emoji} ${mood.label}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildDrawingToolbar() {
    // 情绪系柔和色板：低饱和、粉彩感、情绪表达丰富
    final colors = [
      const Color(0xFFF48FB1), // 柔粉（喜悦）
      const Color(0xFFF06292), // 亮粉（欢欣）
      const Color(0xFFFF8A80), // 暖珊瑚（温暖）
      const Color(0xFFFFAB91), // 淡橘（活力）
      const Color(0xFFFFCC80), // 杏黄（轻快）
      const Color(0xFFFFF59D), // 淡金（希望）
      const Color(0xFFAED581), // 草绿（平静）
      const Color(0xFF81C784), // 青绿（自然）
      const Color(0xFF80DEEA), // 天蓝（宁静）
      const Color(0xFF64B5F6), // 湖蓝（专注）
      const Color(0xFFB39DDB), // 柔紫（灵感）
      const Color(0xFFCE93D8), // 淡紫（梦幻）
      const Color(0xFFA1887F), // 暖棕（沉稳）
      const Color(0xFFE0E0E0), // 浅灰（平和）
      const Color(0xFF90A4AE), // 蓝灰（冷静）
      const Color(0xFFFFFFFF), // 纯白（高光）
      const Color(0xFF37474F), // 深灰蓝（描绘）
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBgOf(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🎨 涂鸦',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  _buildToolButton(
                    icon: Icons.undo,
                    label: '撤销',
                    onPressed: _strokes.isNotEmpty ? _undoDrawing : null,
                  ),
                  const SizedBox(width: 4),
                  _buildToolButton(
                    icon: Icons.redo,
                    label: '重做',
                    onPressed: _redoneStrokes.isNotEmpty ? _redoDrawing : null,
                  ),
                  const SizedBox(width: 8),
                  _buildToolButton(
                    icon: Icons.clear,
                    label: '清空',
                    onPressed: _strokes.isNotEmpty || _redoneStrokes.isNotEmpty ? _clearDrawing : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: colors.map((color) {
              return GestureDetector(
                onTap: () {
                  _commitCurrentStroke();
                  setState(() {
                    _brushColor = color;
                    _brushType = BrushType.pen;
                  });
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _brushColor == color && _brushType == BrushType.pen
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: _brushColor == color && _brushType == BrushType.pen
                        ? [const BoxShadow(blurRadius: 4)]
                        : [],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('粗细'),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _activeSize,
                  min: 2,
                  max: 20,
                  divisions: 9,
                  onChanged: (value) {
                    _commitCurrentStroke();
                    setState(() {
                    if (_brushType == BrushType.eraser) {
                      _eraserSize = value;
                      PreferencesService().setEraserSize(value);
                    } else {
                      _brushSize = value;
                    }
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _brushType == BrushType.eraser
                      ? Colors.grey.withValues(alpha: 0.3)
                      : _brushColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Container(
                  width: _activeSize.clamp(2.0, 24.0),
                  height: _activeSize.clamp(2.0, 24.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildToolButton(
                icon: _brushType == BrushType.eraser
                    ? Icons.brush
                    : Icons.edit,
                label: _brushType == BrushType.eraser ? '画笔' : '橡皮',
                onPressed: _toggleEraser,
                isActive: _brushType == BrushType.eraser,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isActive = false,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
          color: isActive ? AppTheme.primaryColor : (onPressed != null ? null : Colors.grey),
          disabledColor: Colors.grey,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive ? AppTheme.primaryColor : (onPressed != null ? null : Colors.grey),
              ),
        ),
      ],
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<Stroke> strokes;
  final ValueNotifier<List<Offset>> currentPoints;
  final Color currentColor;
  final double currentSize;
  final BrushType currentBrushType;

  _DrawingPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentSize,
    required this.currentBrushType,
  }) : super(repaint: currentPoints);

  @override
  void paint(Canvas canvas, Size size) {
    // 关键：把所有笔迹画进一个独立的离屏图层（saveLayer）。橡皮擦用
    // BlendMode.clear 只清除本图层内已画的笔迹像素，clear 后的区域变透明，
    // 露出下方独立的花园图层——因此橡皮只擦涂鸦、不会擦掉背景。
    // 若不 saveLayer，clear 会作用到底层画布、把花园背景一起清掉。
    //
    // 正在画的笔迹通过 repaint: currentPoints 监听独立重绘，指针移动时
    // 只重绘本层，无需 setState 重建整页。
    canvas.saveLayer(Offset.zero & size, Paint());

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    final live = currentPoints.value;
    if (live.isNotEmpty) {
      _drawStroke(canvas, Stroke(
        points: live,
        color: currentColor,
        size: currentSize,
        brushType: currentBrushType,
      ));
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    final paint = Paint()
      ..strokeWidth = stroke.size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.brushType == BrushType.eraser) {
      // 真正的橡皮擦：清成透明。因为所有笔迹都画在 paint() 里的 saveLayer
      // 离屏图层内，clear 只清除本图层的笔迹像素，restore 合成时露出下层花园。
      paint
        ..color = Colors.transparent
        ..blendMode = BlendMode.clear;
    } else {
      paint.color = stroke.color;
    }

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points[0], stroke.size / 2, paint);
    } else if (stroke.points.length == 2) {
      canvas.drawLine(stroke.points[0], stroke.points[1], paint);
    } else {
      final path = ui.Path();
      final pts = stroke.points;
      path.moveTo(pts[0].dx, pts[0].dy);

      if (pts.length == 3) {
        // 三点：二次贝塞尔曲线直接通过三点
        path.quadraticBezierTo(
          pts[1].dx, pts[1].dy,
          pts[2].dx, pts[2].dy,
        );
      } else {
        // 4+ 点：全程平滑曲线 — 起手曲线到中点，中间逐段贝塞尔，收尾曲线到末点
        path.quadraticBezierTo(
          pts[1].dx, pts[1].dy,
          (pts[1].dx + pts[2].dx) / 2,
          (pts[1].dy + pts[2].dy) / 2,
        );
        for (int i = 1; i < pts.length - 2; i++) {
          path.quadraticBezierTo(
            pts[i + 1].dx, pts[i + 1].dy,
            (pts[i + 1].dx + pts[i + 2].dx) / 2,
            (pts[i + 1].dy + pts[i + 2].dy) / 2,
          );
        }
        path.quadraticBezierTo(
          pts[pts.length - 2].dx, pts[pts.length - 2].dy,
          pts[pts.length - 1].dx, pts[pts.length - 1].dy,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) {
    // 正在画的笔迹由 repaint: currentPoints 驱动重绘，无需在此比较。
    // 这里只处理已提交笔迹与画笔样式的变化。
    return !identical(oldDelegate.strokes, strokes) ||
        oldDelegate.strokes.length != strokes.length ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentSize != currentSize ||
        oldDelegate.currentBrushType != currentBrushType;
  }
}

class _GardenPainter extends CustomPainter {
  final List<MoodRecord> records;
  final bool isDark;

  _GardenPainter({required this.records, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [const Color(0xFF0F172A), const Color(0xFF1A2744)]
            : [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      skyPaint,
    );

    _drawCamouflagePattern(canvas, size);

    final groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [const Color(0xFF1E3A3A), const Color(0xFF152E2E)]
            : [const Color(0xFF86EFAC), const Color(0xFF4ADE80)],
      ).createShader(
          Rect.fromLTWH(0, size.height * 0.65, size.width, size.height * 0.35));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.65, size.width, size.height * 0.35),
      groundPaint,
    );

    final byDay = <String, List<MoodRecord>>{};
    for (final r in records) {
      final key =
          '${r.createdAt.year}-${r.createdAt.month}-${r.createdAt.day}';
      byDay.putIfAbsent(key, () => []).add(r);
    }

    final days = byDay.keys.toList().reversed.toList();
    final totalDays = days.length;
    final gardenTop = size.height * 0.15;
    final gardenBottom = size.height * 0.68;
    final gardenHeight = gardenBottom - gardenTop;

    for (int dayIdx = 0; dayIdx < totalDays && dayIdx < 8; dayIdx++) {
      final dayRecords = byDay[days[dayIdx]]!;
      // 直接取记录自带的日期，避免对未补零的日期键做 DateTime.parse（会抛异常）
      final rawDate = dayRecords.first.createdAt;
      final dayDate = DateTime(rawDate.year, rawDate.month, rawDate.day);
      final daysSinceRecord = today.difference(dayDate);
      final isWilting = daysSinceRecord.inDays >= 7;

      final yRatio = dayIdx / math.max(totalDays - 1, 7);
      final baseY = gardenBottom - yRatio * gardenHeight;

      final count = dayRecords.length;
      final spacing = size.width / (count + 1);

      for (int flowerIdx = 0; flowerIdx < count && flowerIdx < 6; flowerIdx++) {
        final record = dayRecords[flowerIdx];
        final flowerX = spacing * (flowerIdx + 1);
        final flowerY = baseY;

        final flowerSize = 14.0 + record.intensity * 4.0;

        if (isWilting) {
          _drawWiltingFlower(canvas, flowerX, flowerY, flowerSize);
        } else {
          _drawBloomingFlower(
            canvas,
            flowerX,
            flowerY,
            flowerSize,
            Color(record.moodType.colorValue),
            record.moodType.emoji,
          );
        }

        final stemPaint = Paint()
          ..color = isWilting
              ? (isDark ? const Color(0xFF4A5568) : const Color(0xFF9E9E9E))
              : (isDark ? const Color(0xFF66BB6A) : const Color(0xFF4CAF50))
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(flowerX, flowerY),
          Offset(flowerX, flowerY + flowerSize * 2.5),
          stemPaint,
        );
      }

      final labelPaint = TextPainter(
        text: TextSpan(
          text: '${dayDate.month}/${dayDate.day}',
          style: TextStyle(
            fontSize: 10,
            color: isWilting
                ? (isDark ? const Color(0xFF6B7280) : const Color(0xFF9E9E9E))
                : (isDark ? const Color(0xFFB0BEC5) : const Color(0xFF607D8B)),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(8, baseY - 8),
      );
    }
  }

  void _drawBloomingFlower(
    Canvas canvas,
    double x,
    double y,
    double size,
    Color color,
    String emoji,
  ) {
    const petalCount = 5;
    final petalPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < petalCount; i++) {
      final angle = i * (360 / petalCount) * math.pi / 180;
      final petalX = x + size * 0.4 * math.cos(angle);
      final petalY = y + size * 0.4 * math.sin(angle);

      canvas.drawCircle(Offset(petalX, petalY), size * 0.35, petalPaint);
    }

    final centerPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), size * 0.25, centerPaint);

    final hlPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(x - size * 0.08, y - size * 0.08),
      size * 0.12,
      hlPaint,
    );
  }

  void _drawWiltingFlower(Canvas canvas, double x, double y, double size) {
    final wiltPaint = Paint()
      ..color = (isDark ? const Color(0xFF4A5568) : const Color(0xFFBDBDBD))
          .withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final angle = i * (360 / 4) * math.pi / 180 + 0.2;
      final petalX = x + size * 0.35 * math.cos(angle);
      final petalY = y + size * 0.35 * math.sin(angle);
      canvas.drawCircle(Offset(petalX, petalY), size * 0.25, wiltPaint);
    }

    canvas.drawCircle(
      Offset(x, y),
      size * 0.15,
      Paint()
        ..color = (isDark ? const Color(0xFF4A5568) : const Color(0xFF9E9E9E))
            .withValues(alpha: 0.4)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawCamouflagePattern(Canvas canvas, Size size) {
    final patternColors = isDark
        ? [
            const Color(0xFF1E3A3A).withValues(alpha: 0.3),
            const Color(0xFF152E2E).withValues(alpha: 0.2),
            const Color(0xFF2D4A4A).withValues(alpha: 0.25),
          ]
        : [
            const Color(0xFFBBF7D0).withValues(alpha: 0.4),
            const Color(0xFF86EFAC).withValues(alpha: 0.3),
            const Color(0xFF4ADE80).withValues(alpha: 0.25),
          ];

    final random = math.Random(12345);

    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.6;
      final radius = 15 + random.nextDouble() * 30;
      final color = patternColors[i % patternColors.length];

      canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
    }

    for (int i = 0; i < 10; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.6;
      final width = 20 + random.nextDouble() * 40;
      final height = 10 + random.nextDouble() * 20;
      final angle = random.nextDouble() * math.pi * 2;
      final color = patternColors[i % patternColors.length];

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromLTWH(-width / 2, -height / 2, width, height),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GardenPainter oldDelegate) {
    return oldDelegate.records != records || oldDelegate.isDark != isDark;
  }
}

class _ButterflyAnimation extends StatefulWidget {
  const _ButterflyAnimation();

  @override
  State<_ButterflyAnimation> createState() => _ButterflyAnimationState();
}

class _ButterflyAnimationState extends State<_ButterflyAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _xAnimation;
  late Animation<double> _yAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _xAnimation = Tween<double>(begin: 0.1, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _yAnimation = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 1)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 1)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: MediaQuery.of(context).size.width * _xAnimation.value,
          top: 380 * _yAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: const Text(
              '🦋',
              style: TextStyle(fontSize: 24),
            ),
          ),
        );
      },
    );
  }
}

class _StarAnimation extends StatefulWidget {
  const _StarAnimation();

  @override
  State<_StarAnimation> createState() => _StarAnimationState();
}

class _StarAnimationState extends State<_StarAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildStar(0.15, 0.1, 1.0),
        _buildStar(0.35, 0.15, 0.7),
        _buildStar(0.55, 0.08, 0.9),
        _buildStar(0.75, 0.12, 0.6),
        _buildStar(0.85, 0.18, 0.8),
      ],
    );
  }

  Widget _buildStar(double left, double top, double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = (math.sin(_controller.value * math.pi * 2 + delay) + 1) / 2;
        return Positioned(
          left: MediaQuery.of(context).size.width * left,
          top: 380 * top,
          child: Opacity(
            opacity: opacity * 0.8,
            child: const Text('⭐', style: TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }
}
