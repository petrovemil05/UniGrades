import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grade_item.dart';
import '../services/grades_parser.dart';
import '../services/tu_api_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../ui/update_dialog.dart';
import '../viewmodels/grade_monitor_viewmodel.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final GradesParser _parser = GradesParser();
  final TuApiService _api = TuApiService();
  final TextEditingController _fnumController = TextEditingController();
  final TextEditingController _egnController = TextEditingController();

  List<GradeItem>? _grades;
  AverageResult? _averageResult;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  static const String _prefDisclaimerKey = "disclaimer_accepted";

  @override
  void initState() {
    super.initState();
    _checkLogin();
    NotificationService.requestPermissions();
    _checkForUpdates();
    _showDisclaimerIfNeeded();
  }

  Future<void> _showDisclaimerIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_prefDisclaimerKey) ?? false;
    if (accepted) return;

    // Wait for the first frame so the context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Text("⚠️", style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Неофициално приложение",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            "Това приложение е неофициален проект и не е свързано с "
                "Технически университет — София.\n\n"
                "То използва публично достъпните данни от системата Е-Студент "
                "единствено за удобство на студентите.\n\n"
                "Факултетният номер и ЕГН се съхраняват само на устройството ти "
                "и не се изпращат никъде, освен към сървъра на ТУ-София.",
            style: TextStyle(
              color: Color(0xFFBBBBBB),
              fontSize: 14,
              height: 1.55,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  await prefs.setBool(_prefDisclaimerKey, true);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text(
                  "Разбрах",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _checkForUpdates() async {
    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo != null && mounted) {
      UpdateDialog.show(context, updateInfo);
    }
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final fnum = prefs.getString("fnum") ?? "";
    final egn = prefs.getString("egn") ?? "";

    if (fnum.isNotEmpty && egn.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
        _fnumController.text = fnum;
        _egnController.text = egn;
      });
      _loadGrades();
    }
  }

  Future<void> _onLoginClicked() async {
    final fnum = _fnumController.text;
    final egn = _egnController.text;

    if (fnum.isEmpty || egn.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("fnum", fnum);
    await prefs.setString("egn", egn);

    setState(() {
      _isLoggedIn = true;
    });

    _loadGrades();
  }

  void _onLogoutClicked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("fnum");
    await prefs.remove("egn");

    setState(() {
      _isLoggedIn = false;
      _grades = null;
      _averageResult = null;
      _fnumController.clear();
      _egnController.clear();
    });
  }

  Future<void> _loadGrades() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final html = await _api.getHtmlAsync(
        _fnumController.text,
        _egnController.text,
      );
      final result = _parser.parse(html);
      setState(() {
        _grades = result;
        _averageResult = _parser.calculateAverage(result);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getGradeColor(String colorName) {
    switch (colorName) {
      case "Green":
        return const Color(0xFF2ECC71);
      case "Red":
        return const Color(0xFFE74C3C);
      case "Blue":
        return const Color(0xFF3498DB);
      case "Yellow":
        return const Color(0xFFF1C40F);
      case "Cyan":
        return const Color(0xFF1ABC9C);
      case "Orange":
        return const Color(0xFFE67E22);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "Оценки от Е-Студент",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 28,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            const SizedBox(height: 15),
            if (!_isLoggedIn) _buildLoginCard(),
            if (_isLoggedIn) ...[
              _buildActions(),
              const SizedBox(height: 15),
              if (_averageResult != null) ...[
                _buildAverageBadge(),
                const SizedBox(height: 15),
              ],
              if (_isLoading)
                const CircularProgressIndicator(color: Colors.white),
              if (_grades != null) _buildGradesList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAverageBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF2ECC71), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.analytics, color: Color(0xFF2ECC71)),
              const SizedBox(width: 10),
              Text(
                "Среден успех: ${_averageResult!.average.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _averageResult!.semesterLabels.join(' и '),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Вход",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _fnumController,
              decoration: const InputDecoration(
                hintText: "Факултетен номер",
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _egnController,
              decoration: const InputDecoration(
                hintText: "ЕГН",
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              obscureText: true,
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onLoginClicked,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Login", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Consumer<GradeMonitorViewModel>(
      builder: (context, vm, child) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loadGrades,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Обнови",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _onLogoutClicked,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE74C3C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Изход",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (vm.isMonitoring) {
                    await vm.toggle();
                    return;
                  }

                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Следене на оценки'),
                      content: const Text(
                        'Следенето на оценки работи във фонов режим и проверява '
                            'за нови оценки периодично.\n\n'
                            'Това може да увеличи използването на батерията и не гарантира '
                            'абсолютно точни времена на проверка, тъй като Android може '
                            'да ограничава фоновите процеси.\n\n'
                            'Желаете ли да продължите?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Отказ'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Продължи'),
                        ),
                      ],
                    ),
                  );

                  if (result == true) {
                    await vm.toggle();
                  }
                },
                child: Text(vm.toggleLabel),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGradesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _grades!.length,
      itemBuilder: (context, index) {
        final item = _grades![index];
        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: item.isSemester
                ? Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.grade,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16),
                ),
              ),
            )
                : Row(
              children: [
                Expanded(
                  child: Text(
                    item.subject,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.grade,
                    style: TextStyle(
                      color: _getGradeColor(item.color),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}