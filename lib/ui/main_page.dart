import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:unigrades/ui/widgets/timing_selector.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unigrades/models/grade_item.dart';
import 'package:unigrades/services/su_grades_parser.dart';
import 'package:unigrades/services/su_api_service.dart';
import 'package:unigrades/services/tu_grades_parser.dart';
import 'package:unigrades/services/tu_api_service.dart';
import 'package:unigrades/services/notification_service.dart';
import 'package:unigrades/services/update_service.dart';
import 'package:unigrades/ui/update_dialog.dart';
import 'package:unigrades/ui/university_picker_page.dart';
import 'package:unigrades/ui/widgets/login_card.dart';
import 'package:unigrades/ui/widgets/average_badge.dart';
import 'package:unigrades/ui/widgets/grades_list.dart';
import 'package:unigrades/ui/widgets/grade_actions.dart';
import '../models/average_result.dart';
import '../services/grade_monitor_service.dart';
import '../services/fcm_service.dart';
import '../viewmodels/grade_monitor_viewmodel.dart';
import 'package:provider/provider.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String? _university;
  dynamic _api;
  dynamic _parser;

  final TextEditingController _user1Controller = TextEditingController();
  final TextEditingController _user2Controller = TextEditingController();

  List<GradeItem>? _grades;
  AverageResult?   _averageResult;
  bool _isLoading  = false;
  bool _isPulling  = false;
  bool _isLoggedIn = false;
  DateTime? _lastUpdated;
  bool _isCheckingStartup = true;

  int _intervalMinutes = 30;

  static const String _prefDisclaimerKey = 'disclaimer_accepted';

  @override
  void initState() {
    super.initState();
    _init();
    NotificationService.requestPermissions();
    _checkForUpdates();
    _loadInterval();
  }

  Future<void> _loadInterval() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _intervalMinutes = prefs.getInt(GradeMonitorService.prefIntervalKey) ?? 30;
    });
  }

  Future<void> _saveInterval(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(GradeMonitorService.prefIntervalKey, minutes);
    setState(() => _intervalMinutes = minutes);
  }

  Future<void> _init() async {
    await _checkLogin();

    if (mounted) {
      setState(() {
        _isCheckingStartup = false;
      });
    }
  }

  void _setupServices(String university) {
    _university = university;
    if (university == 'TU') {
      _api    = TuApiService();
      _parser = TuGradesParser();
    } else {
      _api    = SuApiService();
      _parser = SuGradesParser();
    }
  }

  Future<void> _checkLogin() async {
    final prefs      = await SharedPreferences.getInstance();
    final university = prefs.getString(UniversityPickerPage.prefKey) ?? '';
    if (university.isEmpty) {
      _redirectToUniversityPicker();
      return;
    }

    setState(() => _setupServices(university));

    final key1 = university == 'TU' ? 'fnum'     : 'username';
    final key2 = university == 'TU' ? 'egn'      : 'password';
    final val1 = prefs.getString(key1) ?? '';
    final val2 = prefs.getString(key2) ?? '';

    if (val1.isNotEmpty && val2.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
        _user1Controller.text = val1;
        _user2Controller.text = val2;
      });
      _loadGrades();
    }
  }

  void _redirectToUniversityPicker() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const UniversityPickerPage(),
        ),
      );
    });
  }

  Future<void> _onLoginClicked() async {
    final fnum = _user1Controller.text.trim();
    final egn = _user2Controller.text.trim();

    if (fnum.isEmpty || egn.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    final key1 = _university == 'TU' ? 'fnum'     : 'username';
    final key2 = _university == 'TU' ? 'egn'      : 'password';

    final oldFnum = prefs.getString(key1) ?? "";
    final oldEgn = prefs.getString(key2) ?? "";

    final credentialsChanged = oldFnum != fnum || oldEgn != egn;

    if (credentialsChanged) {
      await prefs.remove(GradeMonitorService.prefLastCountKey);
    }

    await prefs.setString(key1, fnum);
    await prefs.setString(key2, egn);

    setState(() {
      _isLoggedIn = true;
    });

    await _loadGrades();
  }

  Future<void> _onLogoutClicked() async {
    await FcmService.unregister();

    final service = FlutterBackgroundService();
    final prefs = await SharedPreferences.getInstance();

    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke("stopService");
    }

    await prefs.remove("fnum");
    await prefs.remove("egn");
    await prefs.remove("username");
    await prefs.remove("password");
    await prefs.remove('university');
    await prefs.remove(GradeMonitorService.prefLastCountKey);
    await prefs.remove("fcm_wake_counter");
    await prefs.remove("last_actual_check_at");
    await prefs.setBool('is_monitoring', false);

    await NotificationService.cancel(GradeMonitorService.persistentNotifId);
    await NotificationService.cancel(GradeMonitorService.gradeAlertNotifId);

    if (mounted) {
      context.read<GradeMonitorViewModel>().setMonitoring(false);
    }

    setState(() {
      _isLoggedIn = false;
      _grades = null;
      _averageResult = null;
      _user1Controller.clear();
      _user2Controller.clear();
    });

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const UniversityPickerPage(),
      ),
    );
  }

  Future<void> _loadGrades({bool pulling = false}) async {
    setState(() { _isLoading = true; _isPulling = pulling; });
    try {
      final html   = await _api.getHtmlAsync(_user1Controller.text, _user2Controller.text);
      final result = _parser.parse(html) as List<GradeItem>;
      setState(() {
        _grades        = result;
        _averageResult = _parser.calculateAverage(result) as AverageResult?;
        _lastUpdated   = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; _isPulling = false; });
    }
  }

  Future<void> _checkForUpdates() async {
    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo != null && mounted) UpdateDialog.show(context, updateInfo);
  }

  String get _field1Hint    => _university == 'SU' ? 'Потребителско име' : 'Факултетен номер';
  String get _field2Hint    => _university == 'SU' ? 'Парола'            : 'ЕГН';
  bool   get _field2Obscure => _university == 'SU';
  TextInputType get _field1KeyboardType =>
      _university == 'SU' ? TextInputType.text : TextInputType.number;

  String get _lastUpdatedLabel {
    if (_lastUpdated == null) return '';
    final h = _lastUpdated!.hour.toString().padLeft(2, '0');
    final m = _lastUpdated!.minute.toString().padLeft(2, '0');
    final s = _lastUpdated!.second.toString().padLeft(2, '0');
    return 'Последно обновено: $h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {

    if (_isCheckingStartup) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final uniLabel = _university == 'SU' ? 'СУСИ' : 'Е-Студент';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: _isLoggedIn
            ? IconButton(
          icon: const Icon(Icons.logout, color: Color(0xFFE74C3C)),
          tooltip: 'Изход',
          onPressed: _onLogoutClicked,
        )
            : null,
        title: Text(
          uniLabel,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 26),
        ),
        actions: [
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF2ECC71)),
              tooltip: 'Обнови',
              onPressed: _isLoading ? null : _loadGrades,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadGrades(pulling: true),
        color: const Color(0xFF2ECC71),
        backgroundColor: const Color(0xFF1E1E1E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              const SizedBox(height: 15),
              if (!_isLoggedIn)
                LoginCard(
                  user1Controller:    _user1Controller,
                  user2Controller:    _user2Controller,
                  field1Hint:         _field1Hint,
                  field2Hint:         _field2Hint,
                  field2Obscure:      _field2Obscure,
                  fieldKeyboardType: _field1KeyboardType,
                  onLoginClicked:     _onLoginClicked,
                ),
              if (_isLoggedIn) ...[
                TimingSelector(selectedMinutes: _intervalMinutes, onChanged: _saveInterval),
                const GradeActions(),
                const SizedBox(height: 8),
                if (_lastUpdated != null)
                  Text(
                    _lastUpdatedLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 10),
                if (_averageResult != null) ...[
                  AverageBadge(averageResult: _averageResult!),
                  const SizedBox(height: 15),
                ],
                if (_isLoading && !_isPulling)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                if (_grades != null)
                  GradesList(grades: _grades!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}