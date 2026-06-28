import 'package:e_student/ui/widgets/timing_selector.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:e_student/models/grade_item.dart';
import 'package:e_student/services/su_grades_parser.dart';
import 'package:e_student/services/su_api_service.dart';
import 'package:e_student/services/tu_grades_parser.dart';
import 'package:e_student/services/tu_api_service.dart';
import 'package:e_student/services/notification_service.dart';
import 'package:e_student/services/update_service.dart';
import 'package:e_student/ui/update_dialog.dart';
import 'package:e_student/ui/university_picker_page.dart';
import 'package:e_student/ui/widgets/login_card.dart';
import 'package:e_student/ui/widgets/average_badge.dart';
import 'package:e_student/ui/widgets/grades_list.dart';
import 'package:e_student/ui/widgets/grade_actions.dart';
import '../models/average_result.dart';
import '../services/grade_monitor_service.dart';
import '../services/fcm_service.dart';

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
    await _showDisclaimerIfNeeded();
    await _checkLogin();
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
    if (university.isEmpty) return;

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

  Future<void> _onLoginClicked() async {
    final fnum = _user1Controller.text.trim();
    final egn = _user2Controller.text.trim();

    if (fnum.isEmpty || egn.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    final oldFnum = prefs.getString("fnum") ?? "";
    final oldEgn = prefs.getString("egn") ?? "";

    final credentialsChanged = oldFnum != fnum || oldEgn != egn;

    if (credentialsChanged) {
      await prefs.remove(GradeMonitorService.prefLastCountKey);
    }

    await prefs.setString("fnum", fnum);
    await prefs.setString("egn", egn);

    await FcmService.register();

    setState(() {
      _isLoggedIn = true;
    });

    await _loadGrades();
  }

  Future<void> _onLogoutClicked() async {
    await FcmService.unregister();
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove("fnum");
    await prefs.remove("egn");
    await prefs.remove('university');
    await prefs.remove(GradeMonitorService.prefLastCountKey);
    await prefs.setBool('is_monitoring', false);

    setState(() {
      _isLoggedIn = false;
      _grades = null;
      _averageResult = null;
      _user1Controller.clear();
      _user2Controller.clear();
    });
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

  Future<void> _showDisclaimerIfNeeded() async {
    final prefs    = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_prefDisclaimerKey) ?? false;
    if (accepted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Text('⚠️', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Неофициално приложение',
                  style: TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Това приложение е неофициален проект и не е свързано с '
                'Технически университет — София или Софийски университет.\n\n'
                'То използва публично достъпните данни от студентските системи '
                'единствено за удобство на студентите.\n\n'
                'Данните се съхраняват само на устройството ти '
                'и не се изпращат никъде, освен към сървъра на избрания университет.',
            style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14, height: 1.55),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  await prefs.setBool(_prefDisclaimerKey, true);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text(
                  'Разбрах',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      );
    });
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
    final uniLabel = _university == 'SU' ? 'СУСИ — Оценки' : 'Оценки от Е-Студент';

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
                  field1KeyboardType: _field1KeyboardType,
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