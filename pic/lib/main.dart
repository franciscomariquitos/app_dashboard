import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const VitalSignsApp());
}

// ── Data model ────────────────────────────────────────────────────────────────

enum VitalStatus { normal, warning, danger }

class VitalSign {
  final String name;
  final String unit;
  final IconData icon;
  final Color color;
  double value;
  final double normalMin;
  final double normalMax;
  final double warningMin;
  final double warningMax;
  final List<double> history;

  VitalSign({
    required this.name,
    required this.unit,
    required this.icon,
    required this.color,
    required this.value,
    required this.normalMin,
    required this.normalMax,
    required this.warningMin,
    required this.warningMax,
    List<double>? history,
  }) : history = history ?? [];

  VitalStatus get status {
    if (value >= normalMin && value <= normalMax) return VitalStatus.normal;
    if (value >= warningMin && value <= warningMax) return VitalStatus.warning;
    return VitalStatus.danger;
  }
}

// ── App root ──────────────────────────────────────────────────────────────────

class VitalSignsApp extends StatelessWidget {
  const VitalSignsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vital Signs Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0077B6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const VitalSignsDashboard(),
    );
  }
}

// ── Dashboard ─────────────────────────────────────────────────────────────────

class VitalSignsDashboard extends StatefulWidget {
  const VitalSignsDashboard({super.key});

  @override
  State<VitalSignsDashboard> createState() => _VitalSignsDashboardState();
}

class _VitalSignsDashboardState extends State<VitalSignsDashboard> {
  final _rng = Random();
  Timer? _timer;
  StreamSubscription<Position>? _positionSub;
  bool _isMonitoring = true;
  bool _gpsReady = false;
  String? _gpsError;
  Position? _currentPosition;
  DateTime _lastUpdated = DateTime.now();
  late List<VitalSign> _signs;

  @override
  void initState() {
    super.initState();
    _initSigns();
    _initLocationTracking();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isMonitoring) {
        setState(() {
          _tick();
          _lastUpdated = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() => _gpsError = 'Location services are disabled.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => _gpsError = 'Location permission denied.');
      return;
    }

    try {
      final initial = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = initial;
        _gpsReady = true;
      });

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          _currentPosition = pos;
          _gpsReady = true;
          _gpsError = null;
        });
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _gpsError = 'Unable to read GPS position.');
    }
  }

  void _initSigns() {
    _signs = [
      VitalSign(
        name: 'Heart Rate',
        unit: 'bpm',
        icon: Icons.favorite,
        color: const Color(0xFFE63946),
        value: 72,
        normalMin: 60,
        normalMax: 100,
        warningMin: 50,
        warningMax: 120,
        history: List.generate(20, (_) => 65 + _rng.nextDouble() * 15),
      ),
      VitalSign(
        name: 'Temperature',
        unit: '°C',
        icon: Icons.thermostat,
        color: const Color(0xFFFF9F1C),
        value: 36.6,
        normalMin: 36.1,
        normalMax: 37.2,
        warningMin: 35.5,
        warningMax: 38.5,
        history: List.generate(20, (_) => 36.1 + _rng.nextDouble() * 0.8),
      ),
    ];
  }

  void _tick() {
    const deltas = {
      'Heart Rate': (45.0, 160.0, 4.0),
      'Temperature': (35.0, 40.0, 0.1),
    };

    for (final sign in _signs) {
      final cfg = deltas[sign.name];
      if (cfg == null) continue;
      final (min, max, step) = cfg;
      double v = sign.value + (_rng.nextDouble() - 0.5) * step;
      if (sign.name == 'Temperature') {
        v = double.parse(v.clamp(min, max).toStringAsFixed(1));
      } else {
        v = v.clamp(min, max).roundToDouble();
      }
      sign.value = v;
      sign.history.add(v);
      if (sign.history.length > 30) sign.history.removeAt(0);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Color _statusColor(VitalStatus s) => switch (s) {
        VitalStatus.normal => const Color(0xFF57CC99),
        VitalStatus.warning => const Color(0xFFFFB703),
        VitalStatus.danger => const Color(0xFFE63946),
      };

  VitalStatus get _overallStatus {
    if (_signs.any((v) => v.status == VitalStatus.danger)) return VitalStatus.danger;
    if (_signs.any((v) => v.status == VitalStatus.warning)) return VitalStatus.warning;
    return VitalStatus.normal;
  }

  String get _overallLabel => switch (_overallStatus) {
        VitalStatus.normal => 'STABLE',
        VitalStatus.warning => 'ATTENTION',
        VitalStatus.danger => 'CRITICAL',
      };

  Future<void> _openCurrentLocationInMaps() async {
    final pos = _currentPosition;
    if (pos == null) return;

    final mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}',
    );
    await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1426),
        title: const Row(
          children: [
            Icon(Icons.monitor_heart, color: Color(0xFF00B4D8), size: 26),
            SizedBox(width: 8),
            Text(
              'Vital Signs Monitor',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                Text(
                  _isMonitoring ? 'LIVE' : 'PAUSED',
                  style: TextStyle(
                    color: _isMonitoring ? const Color(0xFF57CC99) : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (_isMonitoring) ...[
                  const SizedBox(width: 4),
                  _PulseDot(),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isMonitoring ? Icons.pause_circle : Icons.play_circle),
            color: const Color(0xFF00B4D8),
            onPressed: () => setState(() => _isMonitoring = !_isMonitoring),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPatientBanner(),
          _buildGpsCard(),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.05,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _signs.length,
              itemBuilder: (_, i) => _VitalCard(sign: _signs[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Last updated: ${_lastUpdated.hour.toString().padLeft(2, '0')}:'
              '${_lastUpdated.minute.toString().padLeft(2, '0')}:'
              '${_lastUpdated.second.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientBanner() {
    final overallColor = _statusColor(_overallStatus);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1426),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0077B6).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF0077B6).withOpacity(0.25),
            child: const Icon(Icons.person, color: Color(0xFF00B4D8), size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('John Doe',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('ID: #10291  ·  Age: 45  ·  Male',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_overallLabel,
                  style: TextStyle(color: overallColor, fontWeight: FontWeight.bold, fontSize: 13)),
              const Text('Overall', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGpsCard() {
    final pos = _currentPosition;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1426),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0077B6).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: Color(0xFF00B4D8), size: 18),
              SizedBox(width: 8),
              Text(
                'GPS Tracking',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_gpsError != null)
            Text(_gpsError!, style: const TextStyle(color: Color(0xFFE63946), fontSize: 12))
          else if (!_gpsReady || pos == null)
            const Text('Getting GPS location...', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _openCurrentLocationInMaps,
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('Show on Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0077B6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Vital sign card ───────────────────────────────────────────────────────────

class _VitalCard extends StatelessWidget {
  final VitalSign sign;
  const _VitalCard({required this.sign});

  static Color _statusColor(VitalStatus s) => switch (s) {
        VitalStatus.normal => const Color(0xFF57CC99),
        VitalStatus.warning => const Color(0xFFFFB703),
        VitalStatus.danger => const Color(0xFFE63946),
      };

  static String _statusLabel(VitalStatus s) => switch (s) {
        VitalStatus.normal => 'NORMAL',
        VitalStatus.warning => 'WARNING',
        VitalStatus.danger => 'CRITICAL',
      };

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(sign.status);
    final valueText = sign.value % 1 == 0
        ? sign.value.toInt().toString()
        : sign.value.toStringAsFixed(1);
    final normalText =
        '${_fmt(sign.normalMin)}–${_fmt(sign.normalMax)} ${sign.unit}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1426),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sign.status == VitalStatus.danger
              ? const Color(0xFFE63946).withOpacity(0.8)
              : sign.color.withOpacity(0.3),
          width: sign.status == VitalStatus.danger ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(sign.icon, color: sign.color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(sign.name,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_statusLabel(sign.status),
                      style: TextStyle(
                          color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Value
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  valueText,
                  style: TextStyle(
                    color: sign.status == VitalStatus.danger
                        ? const Color(0xFFE63946)
                        : Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(sign.unit,
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Normal: $normalText',
                style: const TextStyle(color: Colors.grey, fontSize: 9)),
            const Spacer(),
            // Sparkline
            SizedBox(
              height: 32,
              child: CustomPaint(
                size: const Size(double.infinity, 32),
                painter: _SparklinePainter(values: sign.history, color: sign.color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ── Sparkline painter ─────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(min);
    final maxV = values.reduce(max);
    final range = maxV - minV;
    if (range == 0) return;

    double xOf(int i) => i / (values.length - 1) * size.width;
    double yOf(double v) => size.height - (v - minV) / range * size.height;

    final path = Path()..moveTo(xOf(0), yOf(values[0]));
    for (int i = 1; i < values.length; i++) {
      path.lineTo(xOf(i), yOf(values[i]));
    }

    // Filled area
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.85)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}

// ── Pulsing live indicator dot ────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF57CC99),
            shape: BoxShape.circle,
          ),
        ),
      );
}
