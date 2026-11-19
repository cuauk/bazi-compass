import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:lunar/lunar.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '八字罗盘',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.brown),
      home: CompassPage(),
    );
  }
}

class CompassPage extends StatefulWidget {
  @override
  _CompassPageState createState() => _CompassPageState();
}

class _CompassPageState extends State<CompassPage> {
  final List<String> zhi = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
  final List<int> monthToZhiIndex = [2,3,4,5,6,7,8,9,10,11,0,1];

  DateTime? manualTime;
  DateTime now = DateTime.now();
  Timer? _clockTimer;

  double? _phoneHeading;
  StreamSubscription<CompassEvent>? _compassSub;

  DateTime get effectiveTime => manualTime ?? now;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (manualTime == null) setState(() => now = DateTime.now());
    });
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        setState(() => _phoneHeading = event.heading);
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  Lunar get lunar => Lunar.fromDate(effectiveTime);
  int get monthZhiIndex => monthToZhiIndex[(lunar.getMonth().abs() - 1).clamp(0, 11)];
  int get hourZhiIndex => ((effectiveTime.hour + 1) ~/ 2) % 12;

  int get targetPosIndex {
    final k = (hourZhiIndex - 10 + 12) % 12;
    return (monthZhiIndex + k) % 12;
  }
  String get monthZhi => zhi[monthZhiIndex];
  String get hourZhi => zhi[hourZhiIndex];
  String get targetZhi => zhi[targetPosIndex];

  String directionName(int index) {
    const names = ['正北','北偏东','东北偏北','正东','东南偏东','东南偏南',
                   '正南','西南偏南','西南偏西','正西','西北偏西','西北偏北'];
    return names[index];
  }

  Map<String, String> get bazi {
    final l = Lunar.fromDate(effectiveTime);
    final b = l.getEightChar();
    final t = effectiveTime;
    return {
      '时间': '${t.year}-${t.month.toString().padLeft(2,'0')}-${t.day.toString().padLeft(2,'0')} '
              '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}',
      '农历': '${l.getMonthInChinese()}月${l.getDayInChinese()}',
      '年柱': b.getYear(),
      '月柱': b.getMonth(),
      '日柱': b.getDay(),
      '时柱': b.getTime(),
    };
  }

  Future<void> pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: effectiveTime,
      firstDate: DateTime(1901),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(effectiveTime),
    );
    if (time == null) return;
    setState(() {
      manualTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void resetToNow() => setState(() => manualTime = null);

  @override
  Widget build(BuildContext context) {
    final b = bazi;
    final isManual = manualTime != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('八字罗盘'),
        actions: [
          if (isManual)
            IconButton(
              icon: Icon(Icons.refresh),
              tooltip: '恢复当前时间',
              onPressed: resetToNow,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: CompassPainter(
                  monthZhiIndex: monthZhiIndex,
                  targetPosIndex: targetPosIndex,
                  phoneHeading: _phoneHeading,
                ),
              ),
            ),
            SizedBox(height: 12),
            Text('🎯 指针落点：$targetZhi位（${directionName(targetPosIndex)}）',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red[700])),
            if (_phoneHeading != null)
              Text('📱 手机朝向：${_phoneHeading!.toStringAsFixed(0)}°',
                  style: TextStyle(fontSize: 15, color: Colors.blue)),
            Divider(),
            Card(
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('当前时间：${b['时间']}')),
                        Text(isManual ? '手动' : '自动',
                            style: TextStyle(color: isManual ? Colors.orange : Colors.green)),
                      ],
                    ),
                    Text('农历：${b['农历']}$hourZhi时'),
                    SizedBox(height: 6),
                    Text('八字：${b['年柱']}　${b['月柱']}　${b['日柱']}　${b['时柱']}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: pickDateTime,
                  icon: Icon(Icons.edit_calendar),
                  label: Text('手动输入时间'),
                ),
                if (isManual) ...[
                  SizedBox(width: 12),
                  OutlinedButton(onPressed: resetToNow, child: Text('恢复当前时间')),
                ],
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class CompassPainter extends CustomPainter {
  final int monthZhiIndex;
  final int targetPosIndex;
  final double? phoneHeading;

  CompassPainter({
    required this.monthZhiIndex,
    required this.targetPosIndex,
    required this.phoneHeading,
  });

  final List<String> zhi = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
  final List<String> dirs = ['北','东北','东','东南','南','西南','西','西北'];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 30;

    final circlePaint = Paint()
      ..color = Colors.brown[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, circlePaint);
    canvas.drawCircle(center, radius * 0.72, circlePaint..color = Colors.brown[200]!);

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45 - 90) * pi / 180;
      final textPos = Offset(
        center.dx + (radius + 14) * cos(angle),
        center.dy + (radius + 14) * sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: dirs[i],
          style: TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, textPos - Offset(tp.width / 2, tp.height / 2));
    }

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * pi / 180;
      final textPos = Offset(
        center.dx + (radius - 16) * cos(angle),
        center.dy + (radius - 16) * sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: zhi[i],
          style: TextStyle(fontSize: 18, color: Colors.brown[800], fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, textPos - Offset(tp.width / 2, tp.height / 2));
    }

    void drawPointer(double angleDeg, Color color, double lengthRatio, double width) {
      final angle = (angleDeg - 90) * pi / 180;
      final end = Offset(
        center.dx + radius * lengthRatio * cos(angle),
        center.dy + radius * lengthRatio * sin(angle),
      );
      final paint = Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, end, paint);
      final arrowPaint = Paint()..color = color;
      final path = Path();
      final arrowSize = 12.0;
      path.moveTo(end.dx, end.dy);
      path.lineTo(end.dx - arrowSize * cos(angle - pi / 6), end.dy - arrowSize * sin(angle - pi / 6));
      path.lineTo(end.dx - arrowSize * cos(angle + pi / 6), end.dy - arrowSize * sin(angle + pi / 6));
      path.close();
      canvas.drawPath(path, arrowPaint);
    }

    if (phoneHeading != null) {
      drawPointer(phoneHeading!, Colors.blue, 0.60, 4);
    }
    drawPointer(targetPosIndex * 30.0, Colors.red[700]!, 0.68, 5);

    canvas.drawCircle(center, 9, Paint()..color = Colors.brown[700]!);
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CompassPainter old) =>
      old.monthZhiIndex != monthZhiIndex ||
      old.targetPosIndex != targetPosIndex ||
      old.phoneHeading != phoneHeading;
}
