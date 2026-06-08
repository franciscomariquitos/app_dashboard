import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://mrykxcnzjguytvbvkztf.supabase.co',
    anonKey: 'sb_publishable_tSZ4o4cEupPdJ40bUUbQFQ_r0mLPa57',
  );
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

// ── NAVISense brand colours ───────────────────────────────────────────────────
class _NS {
  static const bg          = Color(0xFF05041A);
  static const bgCard      = Color(0x2611173D);
  static const bgCardDeep  = Color(0x3311173D);
  static const accent      = Color(0xFF4CC9F0);
  static const accentPurple= Color(0xFF7B5EA7);
  static const border      = Color(0x662C3E8F);
  static const borderAccent= Color(0xFF4CC9F0);
  static const textSub     = Color(0xFF8892B0);
  static const live        = Color(0xFF57CC99);
}

BoxDecoration _nsCardDecoration({Color? borderColor}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x331A2B73), Color(0x1C11173D)],
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: borderColor ?? _NS.border.withOpacity(0.7)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 14,
        offset: Offset(0, 8),
      ),
    ],
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String? _error;

  void _login() {
    if (_userCtrl.text.trim() == 'navicare.monitor' &&
        _passCtrl.text.trim() == 'NaviCare2026') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const VitalSignsDashboard(),
        ),
      );
    } else {
      setState(() {
        _error = 'Invalid username or password';
      });
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _NS.bg,
      body: Stack(
        children: [
          const _NsBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: _nsCardDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/navisense-logo.png',
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'NAVIcare Monitor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _userCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        labelStyle: TextStyle(color: _NS.textSub),
                        prefixIcon: Icon(Icons.person, color: _NS.accent),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: _NS.textSub),
                        prefixIcon: Icon(Icons.lock, color: _NS.accent),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFE63946)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _NS.accent.withOpacity(0.10),
                          foregroundColor: _NS.accent,
                          side: const BorderSide(color: Color(0x994CC9F0)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Login'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VitalSignsApp extends StatelessWidget {
  const VitalSignsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.soraTextTheme();

    return MaterialApp(
      title: 'NAVISense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CC9F0),
          brightness: Brightness.dark,
        ),
        fontFamily: 'AdobeGothicStdB',
        textTheme: baseTextTheme.copyWith(
          displayLarge: GoogleFonts.syne(fontWeight: FontWeight.w600),
          displayMedium: GoogleFonts.syne(fontWeight: FontWeight.w600),
          displaySmall: GoogleFonts.syne(fontWeight: FontWeight.w600),
          headlineLarge: GoogleFonts.syne(fontWeight: FontWeight.w600),
          headlineMedium: GoogleFonts.syne(fontWeight: FontWeight.w600),
          headlineSmall: GoogleFonts.syne(fontWeight: FontWeight.w600),
          titleLarge: GoogleFonts.syne(fontWeight: FontWeight.w600),
          titleMedium: GoogleFonts.syne(fontWeight: FontWeight.w600),
          titleSmall: GoogleFonts.syne(fontWeight: FontWeight.w600),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            fontFamily: 'AdobeGothicStdB',
            fontFamilyFallback: const ['Sora', 'sans-serif'],
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            fontFamily: 'AdobeGothicStdB',
            fontFamilyFallback: const ['Sora', 'sans-serif'],
          ),
          bodySmall: baseTextTheme.bodySmall?.copyWith(
            fontFamily: 'AdobeGothicStdB',
            fontFamilyFallback: const ['Sora', 'sans-serif'],
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            fontFamily: 'AdobeGothicStdB',
            fontFamilyFallback: const ['Sora', 'sans-serif'],
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            fontFamily: 'AdobeGothicStdB',
            fontFamilyFallback: const ['Sora', 'sans-serif'],
          ),
          labelSmall: baseTextTheme.labelSmall?.copyWith(
            fontFamily: 'AdobeGothicStdB',
            fontFamilyFallback: const ['Sora', 'sans-serif'],
          ),
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
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
  final _uuid = const Uuid();
  final _supabase = Supabase.instance.client;

  Timer? _timer;
  Timer? _syncTimer;
  StreamSubscription<Position>? _positionSub;

  String _patientName = 'John Doe';
  int _patientAge = 45;
  String _patientSex = 'Male';

  bool _isMonitoring = true;
  bool _isSavingToSupabase = false;
  bool _gpsReady = false;
  String? _gpsError;
  Position? _currentPosition;

  DateTime _lastUpdated = DateTime.now();
  late List<VitalSign> _signs;

  // ── Bluetooth / BLE ────────────────────────────────────────────────────────

  final Guid _serviceUuid = Guid("12345678-1234-1234-1234-1234567890ab");
  final Guid _heartRateUuid = Guid("abcd1234-1234-1234-1234-abcdef123456");
  final Guid _motorIntensityUuid = Guid("dcba4321-1234-1234-1234-abcdef123456");

  BluetoothDevice? _esp32Device;
  BluetoothCharacteristic? _heartRateCharacteristic;
  BluetoothCharacteristic? _motorIntensityCharacteristic;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _bleSub;

  bool _bluetoothConnected = false;
  bool _bluetoothScanning = false;
  String _bluetoothStatus = 'Bluetooth: disconnected';
  double _motorIntensity = 40;

  @override
  void initState() {
    super.initState();
    _initSigns();
    _initLocationTracking();
    _saveTrackerData(showFeedback: false);

    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isMonitoring) {
        setState(() {
          if (!_bluetoothConnected) {
            _tick();
          }
          _lastUpdated = DateTime.now();
        });
      }
    });

    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isMonitoring) {
        _saveTrackerData(showFeedback: false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _syncTimer?.cancel();
    _positionSub?.cancel();
    _scanSub?.cancel();
    _bleSub?.cancel();
    _esp32Device?.disconnect();
    super.dispose();
  }

  Future<void> _connectBluetooth() async {
    
    const bool demoMode = true;

    if (demoMode) {
      setState(() {
        _bluetoothConnected = true;
        _bluetoothScanning = false;
        _bluetoothStatus = 'Bluetooth: connected';
      });
      return;
    }

    if (_bluetoothScanning) return;

    setState(() {
      _bluetoothScanning = true;
      _bluetoothStatus = 'Bluetooth: scanning...';
    });

    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();

    try {
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();

      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final result in results) {
          final name = result.device.platformName;

          if (name == 'ESP32_HeartMonitor') {
            await FlutterBluePlus.stopScan();
            await _scanSub?.cancel();

            _esp32Device = result.device;

            if (!mounted) return;
            setState(() {
              _bluetoothStatus = 'Bluetooth: connecting...';
            });

            await _esp32Device!.connect(timeout: const Duration(seconds: 10));

            final services = await _esp32Device!.discoverServices();

            for (final service in services) {
              if (service.uuid == _serviceUuid) {
                for (final characteristic in service.characteristics) {
                  if (characteristic.uuid == _motorIntensityUuid) {
                    _motorIntensityCharacteristic = characteristic;
                  }

                  if (characteristic.uuid == _heartRateUuid) {
                    _heartRateCharacteristic = characteristic;

                    await characteristic.setNotifyValue(true);

                    _bleSub = characteristic.onValueReceived.listen((value) {
                      final text = utf8.decode(value);
                      final bpm = double.tryParse(text);

                      if (bpm != null) {
                        _updateHeartRateFromBluetooth(bpm);
                      }
                    });

                    if (!mounted) return;
                    setState(() {
                      _bluetoothConnected = true;
                      _bluetoothScanning = false;
                      _bluetoothStatus = 'Bluetooth: connected';
                    });

                    await _sendMotorIntensity(_motorIntensity.round());

                    return;
                  }
                }
              }
            }

            if (!mounted) return;
            setState(() {
              _bluetoothConnected = false;
              _bluetoothScanning = false;
              _bluetoothStatus = 'Bluetooth: characteristic not found';
            });

            return;
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

      await Future.delayed(const Duration(seconds: 8));

      if (!mounted) return;
      if (!_bluetoothConnected) {
        setState(() {
          _bluetoothScanning = false;
          _bluetoothStatus = 'Bluetooth: ESP32 not found';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bluetoothConnected = false;
        _bluetoothScanning = false;
        _bluetoothStatus = 'Bluetooth error: $e';
      });
    }
  }

  void _updateHeartRateFromBluetooth(double bpm) {
    final sign = _signs.firstWhere(
      (s) => s.name == 'Heart Rate',
      orElse: () => _signs.first,
    );

    if (!mounted) return;

    setState(() {
      sign.value = bpm;
      sign.history.add(bpm);

      if (sign.history.length > 30) {
        sign.history.removeAt(0);
      }

      _lastUpdated = DateTime.now();
    });
  }

  Future<void> _disconnectBluetooth() async {
    await _scanSub?.cancel();
    await _bleSub?.cancel();
    await _esp32Device?.disconnect();

    if (!mounted) return;

    setState(() {
      _bluetoothConnected = false;
      _bluetoothScanning = false;
      _bluetoothStatus = 'Bluetooth: disconnected';
    });
  }

  Future<void> _sendMotorIntensity(int percent) async {
    final characteristic = _motorIntensityCharacteristic;
    if (characteristic == null) return;

    final safePercent = percent.clamp(0, 100);

    try {
      await characteristic.write(
        utf8.encode('$safePercent'),
        withoutResponse: false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bluetoothStatus = 'Bluetooth: motor write failed';
      });
    }
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
    ];
  }

  void _tick() {
    const deltas = {
      'Heart Rate': (45.0, 160.0, 4.0),
    };

    for (final sign in _signs) {
      final cfg = deltas[sign.name];
      if (cfg == null) continue;

      final (min, max, step) = cfg;

      final v = (sign.value + (_rng.nextDouble() - 0.5) * step)
          .clamp(min, max)
          .roundToDouble();

      sign.value = v;
      sign.history.add(v);

      if (sign.history.length > 30) {
        sign.history.removeAt(0);
      }
    }
  }

  static Color _statusColor(VitalStatus s) => switch (s) {
        VitalStatus.normal => const Color(0xFF57CC99),
        VitalStatus.warning => const Color(0xFFFFB703),
        VitalStatus.danger => const Color(0xFFE63946),
      };

  VitalStatus get _overallStatus {
    if (_signs.any((v) => v.status == VitalStatus.danger)) {
      return VitalStatus.danger;
    }
    if (_signs.any((v) => v.status == VitalStatus.warning)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  String get _overallLabel => switch (_overallStatus) {
        VitalStatus.normal => 'STABLE',
        VitalStatus.warning => 'ATTENTION',
        VitalStatus.danger => 'CRITICAL',
      };

  String get _databaseStatus => switch (_overallStatus) {
        VitalStatus.normal => 'healthy',
        VitalStatus.warning => 'danger',
        VitalStatus.danger => 'critical',
      };

  Future<void> _saveTrackerData({bool showFeedback = true}) async {
    if (_isSavingToSupabase) return;

    final pos = _currentPosition;
    final locationName = pos == null
        ? 'Unknown location'
        : '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';

    setState(() => _isSavingToSupabase = true);

    try {
      final rowId = _uuid.v4();
      final updatedAt = DateTime.now().toUtc().toIso8601String();
      final inserted = await _supabase.from('tracker_data').insert({
        'id': rowId,
        'person_name': _patientName,
        'status': _databaseStatus,
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        'location_name': locationName,
        'updated_at': updatedAt,
      }).select().single();

      if (!mounted) return;
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tracker saved. id: ${inserted['id']}',
            ),
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final detailsText = e.details?.toString() ?? '';
      final detail = detailsText.isEmpty ? '' : ' Details: $detailsText';
      final hint = e.hint == null || e.hint!.isEmpty
          ? ''
          : ' Hint: ${e.hint}';
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Supabase error: ${e.message}$detail$hint')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send tracker data: $e')),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() => _isSavingToSupabase = false);
    }
  }

  Future<void> _openCurrentLocationInMaps() async {
    final pos = _currentPosition;
    if (pos == null) return;

    final mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}',
    );

    await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _editPatientDetails() async {
    final nameCtrl = TextEditingController(text: _patientName);
    final ageCtrl = TextEditingController(text: _patientAge.toString());
    String selectedSex = _patientSex;

    final result = await showDialog<(String, int, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: _NS.bgCardDeep,
          title: const Text(
            'Edit Patient',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Age',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedSex,
                dropdownColor: const Color(0xFF0D1426),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Sex',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => selectedSex = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsedAge = int.tryParse(ageCtrl.text.trim());
                final parsedName = nameCtrl.text.trim();

                if (parsedName.isEmpty || parsedAge == null || parsedAge <= 0) {
                  return;
                }

                Navigator.of(dialogCtx).pop(
                  (parsedName, parsedAge, selectedSex),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _patientName = result.$1;
      _patientAge = result.$2;
      _patientSex = result.$3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _NS.bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF07092A),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            // Hexagonal NAVISense logo mark
            Image.asset(
              'assets/images/navisense-logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'NAVI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 21,
                      letterSpacing: 1,
                    ),
                  ),
                  TextSpan(
                    text: 'Sense',
                    style: TextStyle(
                      color: _NS.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 21,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _bluetoothConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth,
            ),
            color: _bluetoothConnected ? _NS.live : _NS.accent,
            onPressed: _bluetoothConnected
                ? _disconnectBluetooth
                : _connectBluetooth,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                if (_isMonitoring)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _NS.live.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _NS.live.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulseDot(),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE LINK',
                          style: TextStyle(
                            color: _NS.live,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    'PAUSED',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isMonitoring ? Icons.pause_circle : Icons.play_circle),
            color: _NS.accent,
            onPressed: () => setState(() => _isMonitoring = !_isMonitoring),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _NsBackground(),
          Column(
            children: [
              _buildPatientBanner(),
              _buildBluetoothCard(),
              _buildMotorControlCard(),
              _buildGpsCard(),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _signs.length == 1 ? 1 : 2,
                    childAspectRatio: _signs.length == 1 ? 1.8 : 1.05,
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
                  style: const TextStyle(color: _NS.textSub, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _nsCardDecoration(
        borderColor: _bluetoothConnected ? _NS.live.withOpacity(0.35) : _NS.border,
      ),
      child: Row(
        children: [
          Icon(
            _bluetoothConnected
                ? Icons.bluetooth_connected
                : Icons.bluetooth,
            color: _bluetoothConnected ? _NS.live : _NS.accent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _bluetoothStatus,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          ElevatedButton(
            onPressed: _bluetoothConnected
                ? _disconnectBluetooth
                : _connectBluetooth,
            style: ElevatedButton.styleFrom(
              backgroundColor: _bluetoothConnected
                  ? const Color(0xCCB42331)
                  : _NS.accent.withOpacity(0.08),
              foregroundColor: _bluetoothConnected ? Colors.white : _NS.accent,
              side: _bluetoothConnected
                  ? null
                  : const BorderSide(color: Color(0x994CC9F0), width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(_bluetoothConnected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildMotorControlCard() {
    final intensityLabel = '${_motorIntensity.round()}%';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _nsCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: _NS.accent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Motor Intensity',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _NS.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _NS.accent.withOpacity(0.25)),
                ),
                child: Text(
                  intensityLabel,
                  style: const TextStyle(
                    color: _NS.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _NS.accent,
              inactiveTrackColor: _NS.textSub.withOpacity(0.25),
              thumbColor: _NS.accent,
              overlayColor: _NS.accent.withOpacity(0.18),
              trackHeight: 3.5,
            ),
            child: Slider(
              min: 0,
              max: 100,
              divisions: 100,
              value: _motorIntensity,
              onChanged: (value) {
                setState(() => _motorIntensity = value);
              },
              onChangeEnd: (value) {
                _sendMotorIntensity(value.round());
              },
            ),
          ),
          Text(
            _bluetoothConnected
                ? 'Sent to wearable when adjusted.'
                : 'Connect Bluetooth to apply on device.',
            style: const TextStyle(color: _NS.textSub, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientBanner() {
    final overallColor = _statusColor(_overallStatus);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _nsCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge label row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _NS.accent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _NS.accent.withOpacity(0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 5, height: 5,
                      decoration: const BoxDecoration(
                        color: _NS.accent, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text(
                      'WEARABLE LAYER',
                      style: TextStyle(
                        color: _NS.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _NS.accent.withOpacity(0.07),
                child: const Icon(Icons.person, color: _NS.accent, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _patientName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Age: $_patientAge  ·  $_patientSex',
                      style: const TextStyle(color: _NS.textSub, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _editPatientDetails,
                icon: const Icon(Icons.edit, color: _NS.accent, size: 18),
                tooltip: 'Edit patient',
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: overallColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: overallColor.withOpacity(0.26)),
                    ),
                    child: Text(
                      _overallLabel,
                      style: TextStyle(
                        color: overallColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Overall',
                    style: TextStyle(color: _NS.textSub, fontSize: 10),
                  ),
                ],
              ),
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
      decoration: _nsCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: _NS.accent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'GPS Tracking',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _NS.accentPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _NS.accentPurple.withOpacity(0.26)),
                ),
                child: const Text(
                  'ANDROID BRIDGE',
                  style: TextStyle(
                    color: _NS.accentPurple,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_gpsError != null)
            Text(
              _gpsError!,
              style: const TextStyle(color: Color(0xFFE63946), fontSize: 12),
            )
          else if (!_gpsReady || pos == null)
            const Text(
              'Getting GPS location...',
              style: TextStyle(color: _NS.textSub, fontSize: 13),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _openCurrentLocationInMaps,
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('Show on Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _NS.accent.withOpacity(0.06),
                    foregroundColor: _NS.accent,
                    side: const BorderSide(color: Color(0x994CC9F0), width: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
      decoration: _nsCardDecoration(
        borderColor: sign.status == VitalStatus.danger
            ? const Color(0xCCB42331)
            : _NS.border.withOpacity(0.9),
      ).copyWith(
        border: Border.all(
          color: sign.status == VitalStatus.danger
              ? const Color(0xCCB42331)
              : _NS.border.withOpacity(0.9),
          width: sign.status == VitalStatus.danger ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(sign.icon, color: sign.color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sign.name,
                    style: const TextStyle(color: _NS.textSub, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(sign.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  valueText,
                  style: TextStyle(
                    color: sign.status == VitalStatus.danger
                        ? const Color(0xFFE63946)
                        : Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    sign.unit,
                    style: const TextStyle(color: _NS.textSub, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Normal: $normalText',
              style: const TextStyle(color: _NS.textSub, fontSize: 11),
            ),
            const Spacer(),
            SizedBox(
              height: 32,
              child: CustomPaint(
                size: const Size(double.infinity, 32),
                painter: _SparklinePainter(
                  values: sign.history,
                  color: sign.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  }
}

// ── Sparkline painter ─────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SparklinePainter({
    required this.values,
    required this.color,
  });

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
          colors: [
            color.withOpacity(0.3),
            color.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

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
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _NsBackground extends StatelessWidget {
  const _NsBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0D35),
                  Color(0xFF0A0B2A),
                  Color(0xFF07071E),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -90,
            child: Container(
              width: 420,
              height: 420,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x663AA5FF), Color(0x003AA5FF)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 60,
            right: -110,
            child: Container(
              width: 460,
              height: 460,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x55385CFF), Color(0x00385CFF)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _GridOverlayPainter()),
          ),
        ],
      ),
    );
  }
}

class _GridOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const gridGap = 38.0;
    final paint = Paint()
      ..color = const Color(0x88AFC4FF).withOpacity(0.08)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += gridGap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += gridGap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Pulsing live indicator dot ────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
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
}