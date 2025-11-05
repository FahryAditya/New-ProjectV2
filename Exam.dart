// main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

// =============================================================================
// BAGIAN 1: MODEL (DATA)
// =============================================================================

enum UserRole { guru, siswa }
enum AppState { login, dashboard, createExam, examActive, resultReport, reviewResult } // reviewResult ditambahkan untuk tinjauan setelah ujian

class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  User(this.id, this.email, this.name, this.role);
}

class Question {
  final String id;
  final String text;
  final List<String> originalOptions; // Opsi asli
  final String correctAnswer; // A, B, C, D (Kunci Jawaban sebelum diacak)
  final Map<String, String> shuffledOptions; // {A: 'Opsi C asli', B: 'Opsi A asli', ...} (Opsi yang sudah diacak)
  
  Question({
    required this.id,
    required this.text,
    required this.originalOptions,
    required this.correctAnswer,
  }) : shuffledOptions = _shuffleOptions(originalOptions); // Inisialisasi pengacakan

  static Map<String, String> _shuffleOptions(List<String> options) {
    final shuffled = List<String>.from(options)..shuffle(Random());
    final Map<String, String> result = {};
    for (int i = 0; i < options.length; i++) {
      // Keys adalah A, B, C, D
      result[String.fromCharCode('A'.codeUnitAt(0) + i)] = shuffled[i];
    }
    return result;
  }
}

class Exam {
  final String id;
  final String title;
  final int durationMinutes;
  final String token;
  final List<Question> originalQuestions;
  final List<Question> shuffledQuestions; // Soal yang sudah diacak
  
  // PERPANJANGAN (Rekomendasi): Tambahkan batas waktu ujian (untuk manajemen)
  final DateTime? startTime;
  final DateTime? endTime;
  
  Exam({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.token,
    required this.originalQuestions,
    this.startTime,
    this.endTime,
  }) : shuffledQuestions = List<Question>.from(originalQuestions)..shuffle(Random()); // Acak urutan soal
  
  // Memudahkan akses, gunakan soal yang sudah diacak
  List<Question> get questions => shuffledQuestions;
}

class ExamResult {
  final String userId;
  final String examId;
  final String userName;
  final Map<String, String?> answers; // {questionId: selectedOption}
  final int score;
  final Duration timeTaken;
  final int cheatingCount;
  final DateTime submissionTime;

  ExamResult({
    required this.userId,
    required this.examId,
    required this.userName,
    required this.answers,
    required this.score,
    required this.timeTaken,
    required this.cheatingCount,
    required this.submissionTime,
  });
}

class CheatingLog {
  final String userId;
  final DateTime timestamp;
  final String type; // e.g., 'FOCUS_LOST', 'CTRL_C', 'MULTIPLE_SESSION'
  final String description;
  CheatingLog(this.userId, this.timestamp, this.type, this.description);
}

// =============================================================================
// BAGIAN 7: SIMULASI BACKEND (FakeDatabase)
// =============================================================================

class FakeDatabase {
  static final User _dummyGuru = User('g1', 'guru@pro.id', 'Bambang Sudiro', UserRole.guru);
  static final List<User> users = [_dummyGuru];
  static final List<Exam> exams = [];
  static final List<ExamResult> results = [];
  static final List<CheatingLog> cheatingLogs = [];
  
  // PERPANJANGAN: Status Siswa Aktif (Real-time Simulasi)
  // {examId: {userId: {progress: 5/10, status: 'Active', cheatingCount: 1, userName: 'Siswa X'}}}
  static final Map<String, Map<String, Map<String, dynamic>>> activeStudentStatus = {}; 

  // --- Mock Authentication ---
  static User? login(String email, String password, UserRole role) {
    if (role == UserRole.guru && email == 'guru@pro.id' && password == 'admin123') {
      return _dummyGuru;
    }
    return null;
  }

  static Exam? loginStudent(String token) {
    try {
      final originalExam = exams.firstWhere((e) => e.token == token);
      final now = DateTime.now();
      
      // PERPANJANGAN (Rekomendasi): Cek Batas Waktu Token
      if (originalExam.startTime != null && now.isBefore(originalExam.startTime!)) {
        throw Exception("Ujian belum dimulai. Tunggu hingga ${originalExam.startTime!.hour.toString().padLeft(2, '0')}:${originalExam.startTime!.minute.toString().padLeft(2, '0')}.");
      }
      if (originalExam.endTime != null && now.isAfter(originalExam.endTime!)) {
        throw Exception("Ujian sudah ditutup. Waktu berakhir: ${originalExam.endTime!.hour.toString().padLeft(2, '0')}:${originalExam.endTime!.minute.toString().padLeft(2, '0')}.");
      }
      
      // Buat instance Exam BARU agar soal dan opsi teracak
      return Exam(
        id: originalExam.id,
        title: originalExam.title,
        durationMinutes: originalExam.durationMinutes,
        token: originalExam.token,
        originalQuestions: originalExam.originalQuestions,
        startTime: originalExam.startTime,
        endTime: originalExam.endTime,
      );
      
    } catch (e) {
      if (e is Exception) rethrow;
      return null;
    }
  }

  // --- Mock Exam Management ---
  static void createExam(Exam exam) {
    exams.add(exam);
  }

  static List<Exam> getExams() => exams;

  static ExamResult submitExam(ExamResult result) {
    results.add(result);
    // Hapus status aktif setelah submit
    activeStudentStatus[result.examId]?.remove(result.userId);
    return result;
  }

  static List<ExamResult> getExamResults(String examId) {
    return results.where((r) => r.examId == examId).toList();
  }

  // --- Mock Cheating Log ---
  static void logCheating(String userId, String type, String description) {
    final log = CheatingLog(userId, DateTime.now(), type, description);
    cheatingLogs.add(log);
    print('🚨 CHEATING LOGGED: ${log.type} - ${log.description}');
    
    // Update status cheating di real-time monitoring
    final currentExamId = activeStudentStatus.keys.firstWhere((id) => activeStudentStatus[id]!.containsKey(userId), orElse: () => '');
    if (currentExamId.isNotEmpty) {
       final status = activeStudentStatus[currentExamId]![userId]!;
       status['cheatingCount'] = status['cheatingCount'] + 1;
       status['status'] = 'Pelanggaran!';
    }
  }
  
  // PERPANJANGAN: Real-time Update dari Siswa
  static void updateStudentProgress(String examId, String userId, int answeredCount, int totalQuestions, String userName) {
    activeStudentStatus.putIfAbsent(examId, () => {});
    activeStudentStatus[examId]!.putIfAbsent(userId, () => {
      'userName': userName,
      'progress': '0/0',
      'status': 'Aktif',
      'cheatingCount': 0,
      'startTime': DateTime.now(),
    });
    
    final status = activeStudentStatus[examId]![userId]!;
    status['progress'] = '$answeredCount/$totalQuestions';
    if (status['status'] != 'Pelanggaran!') { // Jangan timpa status pelanggaran
        status['status'] = answeredCount > 0 ? 'Mengerjakan' : 'Aktif';
    }
  }
}

// =============================================================================
// BAGIAN 9: TEKNIS AI PROMPT ENGINE (Simulasi)
// =============================================================================

List<Question> generateQuestions(String prompt) {
  final random = Random();
  final topicMatch = RegExp(r'topik\s+([\w\s]+)').firstMatch(prompt);
  final numberMatch = RegExp(r'(\d+)\s+soal').firstMatch(prompt);

  final topic = topicMatch?.group(1)?.trim() ?? 'Pelajaran Umum';
  final count = numberMatch != null ? int.parse(numberMatch.group(1)!) : 5;
  final effectiveCount = min(count, 15); // Batasi maksimal 15 soal untuk keamanan

  final List<Question> generated = [];
  for (int i = 0; i < effectiveCount; i++) {
    final id = 'Q${DateTime.now().microsecondsSinceEpoch}_$i';
    final correctOptChar = ['A', 'B', 'C', 'D'][random.nextInt(4)];
    
    // Tentukan index jawaban benar
    final correctIndex = ['A', 'B', 'C', 'D'].indexOf(correctOptChar);
    
    // Sederhanakan Opsi, biarkan logika acak di Model
    final originalOptions = List<String>.from(['Opsi A', 'Opsi B', 'Opsi C', 'Opsi D']);
    // Masukkan jawaban benar pada posisi yang sesuai untuk pengujian
    originalOptions[correctIndex] = 'Opsi KUNCI JAWABAN';
    
    generated.add(Question(
      id: id,
      text: 'AI Soal ${i + 1} (${topic}): Ini adalah pertanyaan pilihan ganda tentang **${topic}** yang dibuat secara otomatis.',
      originalOptions: originalOptions,
      correctAnswer: correctOptChar,
    ));
  }
  return generated;
}

// =============================================================================
// CONTROLLER UTAMA (State Management)
// =============================================================================

class AppController extends ChangeNotifier {
  AppState _currentState = AppState.login;
  User? _currentUser;
  Exam? _activeExam;
  Map<String, String?> _studentAnswers = {};
  int _cheatingCounter = 0;
  DateTime? _examStartTime;
  Duration? _timeTaken;
  String? _loginToken;
  
  // PERPANJANGAN: Properti Mode Gelap
  ThemeMode _themeMode = ThemeMode.system; // Default ke sistem
  Timer? _dashboardTimer; // Timer untuk simulasi real-time update guru

  AppState get currentState => _currentState;
  User? get currentUser => _currentUser;
  Exam? get activeExam => _activeExam;
  Map<String, String?> get studentAnswers => _studentAnswers;
  int get cheatingCounter => _cheatingCounter;
  String? get loginToken => _loginToken;
  ExamResult? get lastSubmittedResult => FakeDatabase.results.lastOrNull;
  ThemeMode get themeMode => _themeMode; // PERPANJANGAN: Getter Mode Gelap

  void _navigateTo(AppState state) {
    _currentState = state;
    notifyListeners();
  }

  // PERPANJANGAN: Fungsi untuk mengubah mode tema
  void toggleTheme(ThemeMode? newMode) {
    if (newMode != null) {
      _themeMode = newMode;
      print('Tema diubah menjadi: $_themeMode');
      notifyListeners();
    }
  }

  // BAGIAN 2: LOGIN
  void loginGuru(String email, String password) {
    _currentUser = FakeDatabase.login(email, password, UserRole.guru);
    if (_currentUser != null) {
      _navigateTo(AppState.dashboard);
    } else {
      throw Exception("Login Guru gagal. Email/password salah.");
    }
  }

  Future<void> loginSiswa(String token) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    _activeExam = FakeDatabase.loginStudent(token);
    if (_activeExam != null) {
      _loginToken = token;
      
      _studentAnswers = {for (var q in _activeExam!.questions) q.id: null};
      
      final studentId = 's${Random().nextInt(1000)}'; // ID siswa dibuat di sini
      _currentUser = User(studentId, 'siswa@$token', 'Siswa ${Random().nextInt(999)}', UserRole.siswa);
      
      // Daftarkan siswa ke real-time status
      FakeDatabase.updateStudentProgress(
        _activeExam!.id, 
        _currentUser!.id, 
        0, 
        _activeExam!.questions.length,
        _currentUser!.name,
      );
      
      _navigateTo(AppState.examActive);
      _examStartTime = DateTime.now();
      _cheatingCounter = 0;
    } else {
      throw Exception("Token Ujian tidak valid atau ujian belum tersedia.");
    }
  }

  void logout() {
    _dashboardTimer?.cancel(); // Hentikan timer dashboard
    
    _currentUser = null;
    _activeExam = null;
    _studentAnswers = {};
    _cheatingCounter = 0;
    _examStartTime = null;
    _timeTaken = null;
    _loginToken = null;
    _navigateTo(AppState.login);
  }
  
  // BAGIAN 3: DASHBOARD GURU
  void createNewExam({
    required String title,
    required int durationMinutes,
    required List<Question> questions,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    if (questions.isEmpty) return;
    
    final token = 'EXAM${Random().nextInt(99999).toString().padLeft(5, '0')}';
    final newExam = Exam(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      durationMinutes: durationMinutes,
      token: token,
      originalQuestions: questions,
      startTime: startTime,
      endTime: endTime,
    );
    
    FakeDatabase.createExam(newExam);
    _navigateTo(AppState.dashboard);
  }
  
  // PERPANJANGAN: Inisiasi Real-time Monitoring untuk Guru
  void startDashboardMonitoring() {
    if (_dashboardTimer != null) _dashboardTimer!.cancel();
    
    // Simulasi pembaruan setiap 2 detik
    _dashboardTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentState == AppState.dashboard) {
        notifyListeners();
      }
    });
  }
  
  Map<String, Map<String, dynamic>> getActiveStudentStatus(String examId) {
    return FakeDatabase.activeStudentStatus[examId] ?? {};
  }
  
  List<CheatingLog> getAllCheatingLogs() {
    return FakeDatabase.cheatingLogs;
  }

  // BAGIAN 4: HALAMAN UJIAN SISWA
  void submitAnswer(String questionId, String? selectedOption) {
    if (_currentState != AppState.examActive || _activeExam == null || _currentUser == null) return;
    
    _studentAnswers[questionId] = selectedOption;
    print('Auto-save: Jawaban $questionId disimpan: $selectedOption');
    
    // Update real-time progress siswa
    final answeredCount = _studentAnswers.values.where((a) => a != null).length;
    FakeDatabase.updateStudentProgress(
        _activeExam!.id, 
        _currentUser!.id, 
        answeredCount, 
        _activeExam!.questions.length,
        _currentUser!.name
    );
    
    notifyListeners();
  }

  void finishExam({bool isAutomatic = false}) {
    if (_activeExam == null || _currentUser == null || _examStartTime == null) return;
    
    if (isAutomatic) {
      FakeDatabase.logCheating(_currentUser!.id, 'AUTO_SUBMIT', 'Ujian dikirim otomatis karena waktu habis atau pelanggaran batas.');
    }

    _timeTaken = DateTime.now().difference(_examStartTime!);
    int correctCount = 0;
    final questions = _activeExam!.questions;
    for (var q in questions) {
      // Periksa jawaban siswa dengan kunci jawaban yang disimpan di model Question
      // Note: q.correctAnswer adalah A, B, C, D yang mereferensikan opsi yang benar 
      // dari shuffledOptions saat ini.
      if (_studentAnswers[q.id] == q.correctAnswer) {
        correctCount++;
      }
    }
    
    final score = (correctCount / questions.length * 100).round();

    final result = ExamResult(
      userId: _currentUser!.id,
      examId: _activeExam!.id,
      userName: _currentUser!.name,
      answers: _studentAnswers,
      score: score,
      timeTaken: _timeTaken!,
      cheatingCount: _cheatingCounter,
      submissionTime: DateTime.now(),
    );

    FakeDatabase.submitExam(result);
    _navigateTo(AppState.resultReport);
  }

  // BAGIAN 5: ANTI KECURANGAN
  void incrementCheatingCounter(String type, String description) {
    if (_currentState != AppState.examActive || _currentUser == null) return;
    
    _cheatingCounter++;
    FakeDatabase.logCheating(_currentUser!.id, type, description);

    // Jika log mencapai batas tertentu → ujian langsung dikirim otomatis
    if (_cheatingCounter >= 3) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(content: Text('🛑 PELANGGARAN BERAT! Ujian Anda otomatis dikirim.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      finishExam(isAutomatic: true);
    } else {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(content: Text('Peringatan Kecurangan (${_cheatingCounter}/3): $description')),
      );
    }
    notifyListeners();
  }

  List<ExamResult> getExamResults(String examId) {
    return FakeDatabase.getExamResults(examId);
  }

  // Fungsi untuk mendapatkan data log kecurangan per siswa
  List<CheatingLog> getStudentCheatingLogs(String userId) {
    return FakeDatabase.cheatingLogs.where((log) => log.userId == userId).toList();
  }
  
  void goToReviewResult() {
    if (_currentState == AppState.resultReport) {
      _navigateTo(AppState.reviewResult);
    }
  }
  
  void finishReviewAndLogout() {
    logout();
  }
}

// =============================================================================
// MAIN APP
// =============================================================================

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Simulasi pembuatan ujian awal oleh Guru (agar siswa bisa login)
  final initialQuestions = generateQuestions("Buat 10 soal pilihan ganda topik Tumbuhan");
  FakeDatabase.createExam(Exam(
    id: 'e001', 
    title: 'Ujian IPA Biologi', 
    durationMinutes: 10, 
    token: 'BIOLOGI24', 
    originalQuestions: initialQuestions,
    startTime: DateTime.now().subtract(const Duration(minutes: 5)), // Ujian sudah mulai
    endTime: DateTime.now().add(const Duration(hours: 1)), // Ujian berakhir 1 jam lagi
  ));

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppController(),
      child: const OnlineExamApp(),
    ),
  );
}
// Wrapper untuk ChangeNotifierProvider
class ChangeNotifierProvider extends InheritedNotifier<AppController> {
  const ChangeNotifierProvider({
    super.key,
    required AppController create,
    required Widget child,
  }) : super(notifier: create, child: child);

  static AppController of(BuildContext context, {bool listen = true}) {
    if (listen) {
      return context.dependOnInheritedWidgetOfExactType<ChangeNotifierProvider>()!.notifier!;
    }
    return context.findAncestorWidgetOfExactType<ChangeNotifierProvider>()!.notifier!;
  }
}


class OnlineExamApp extends StatelessWidget {
  const OnlineExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dengarkan controller agar perubahan tema memicu rebuild
    final controller = ChangeNotifierProvider.of(context); 

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Pro-Exam Pro (Anti-Cheating)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      // Gunakan themeMode dari Controller
      themeMode: controller.themeMode, 
      home: const MainRouter(),
    );
  }
}

class MainRouter extends StatelessWidget {
  const MainRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChangeNotifierProvider.of(context);

    Widget page;
    switch (controller.currentState) {
      case AppState.login:
        page = const LoginPage();
        break;
      case AppState.dashboard:
        page = const TeacherDashboardPage();
        break;
      case AppState.createExam:
        page = const CreateExamPage();
        break;
      case AppState.examActive:
        // RawKeyboardListener harus di level tertinggi
        page = RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: (event) {
            // Deteksi Shortcut Keyboard
            if (event is RawKeyDownEvent) {
              if (event.isKeyPressed(LogicalKeyboardKey.controlLeft) || event.isKeyPressed(LogicalKeyboardKey.controlRight)) {
                if (event.isKeyPressed(LogicalKeyboardKey.keyC) || event.isKeyPressed(LogicalKeyboardKey.keyV) || event.isKeyPressed(LogicalKeyboardKey.tab)) {
                  controller.incrementCheatingCounter('KEYBOARD', 'Shortcut dilarang (Ctrl+C/V/Tab) terdeteksi.');
                }
              }
              if (event.isKeyPressed(LogicalKeyboardKey.altLeft) && event.isKeyPressed(LogicalKeyboardKey.tab)) {
                  controller.incrementCheatingCounter('KEYBOARD', 'Shortcut Alt+Tab terdeteksi.');
              }
              if (event.isKeyPressed(LogicalKeyboardKey.printScreen)) {
                  controller.incrementCheatingCounter('KEYBOARD', 'Print Screen terdeteksi.');
              }
            }
          },
          child: StudentExamPage(exam: controller.activeExam!),
        );
        break;
      case AppState.resultReport:
        page = const ResultReportPage();
        break;
      case AppState.reviewResult:
        page = const ReviewResultPage();
        break;
    }

    // Wrap untuk responsif
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: page,
        ),
      ),
    );
  }
}

// =============================================================================
// VIEWS (UI)
// =============================================================================

// --- LoginPage (BAGIAN 2 & Theme) ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>(); 
  final _emailController = TextEditingController(text: 'guru@pro.id');
  final _passController = TextEditingController(text: 'admin123');
  final _tokenController = TextEditingController(text: 'BIOLOGI24');
  bool _isGuruLogin = true;
  String? _error;

  void _login(AppController controller) async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _error = null);
    try {
      if (_isGuruLogin) {
        controller.loginGuru(_emailController.text, _passController.text);
      } else {
        await controller.loginSiswa(_tokenController.text);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChangeNotifierProvider.of(context);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Theme Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DropdownButton<ThemeMode>(
                value: controller.themeMode,
                icon: const Icon(Icons.palette),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('Tema Sistem')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Tema Terang')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Tema Gelap')),
                ],
                onChanged: controller.toggleTheme,
              ),
            ],
          ),
          
          Text('Pro-Exam Pro', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(label: const Text('Guru'), selected: _isGuruLogin, onSelected: (v) => setState(() => _isGuruLogin = true)),
              const SizedBox(width: 20),
              ChoiceChip(label: const Text('Siswa (Token)'), selected: !_isGuruLogin, onSelected: (v) => setState(() => _isGuruLogin = false)),
            ],
          ),
          const SizedBox(height: 20),
          Form(
            key: _loginFormKey,
            child: SizedBox(
              width: 400,
              child: _isGuruLogin
                  ? Column(children: [
                      TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Guru'), validator: (v) => v!.isEmpty ? 'Email wajib diisi' : null), 
                      TextFormField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), validator: (v) => v!.isEmpty ? 'Password wajib diisi' : null)
                    ])
                  : TextFormField(controller: _tokenController, decoration: const InputDecoration(labelText: 'Token Ujian'), validator: (v) => v!.isEmpty ? 'Token wajib diisi' : null),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: () => _login(controller), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)), child: Text(_isGuruLogin ? 'Masuk Guru' : 'Mulai Ujian')),
        ],
      ),
    );
  }
}

// --- TeacherDashboardPage (BAGIAN 3, Monitoring & Reports) ---
class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  
  @override
  void initState() {
    super.initState();
    // Mulai monitoring saat dashboard dimuat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChangeNotifierProvider.of(context, listen: false).startDashboardMonitoring();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dengarkan controller untuk menerima update timer
    final controller = ChangeNotifierProvider.of(context, listen: true);
    final exams = FakeDatabase.getExams();
    final allResults = FakeDatabase.results; 
    final allCheatingLogs = controller.getAllCheatingLogs();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard Guru (${controller.currentUser?.name})'),
        actions: [
          // Dropdown Theme Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<ThemeMode>(
              value: controller.themeMode,
              icon: const Icon(Icons.palette),
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('Sistem')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Terang')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Gelap')),
              ],
              onChanged: controller.toggleTheme,
            ),
          ),
          // Tombol Laporan Kecurangan Global
          IconButton(
            icon: const Icon(Icons.warning_amber), 
            onPressed: () {
              showDialog(
                context: context, 
                builder: (ctx) => _buildGlobalCheatingReport(ctx, allCheatingLogs),
              );
            },
            tooltip: 'Laporan Kecurangan Global',
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: controller.logout)
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => controller._navigateTo(AppState.createExam),
        label: const Text('Buat Ujian Baru'),
        icon: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📚 Daftar Ujian Aktif', style: Theme.of(context).textTheme.headlineMedium),
            const Divider(),
            if (exams.isEmpty) const Text('Belum ada ujian yang dibuat.'),
            
            // Tampilkan kartu untuk setiap ujian
            ...exams.map((exam) {
              final examResults = allResults.where((r) => r.examId == exam.id).toList();
              final activeStudents = controller.getActiveStudentStatus(exam.id).values.toList(); 
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile( // ExpansionTile untuk Monitoring
                  title: Text(exam.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Token: ${exam.token} | Durasi: ${exam.durationMinutes} Menit | Soal: ${exam.questions.length}'),
                  trailing: Text('Aktif: ${activeStudents.length} | Selesai: ${examResults.length}'),
                  children: [
                    // --- Monitoring Real-time ---
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monitor Siswa Aktif (${activeStudents.length})', style: Theme.of(context).textTheme.titleSmall),
                          const Divider(),
                          if (activeStudents.isEmpty) const Text('Tidak ada siswa yang sedang mengerjakan ujian ini.'),
                          ...activeStudents.map((status) {
                             final timeSinceStart = DateTime.now().difference(status['startTime'] as DateTime);
                             final timeDisplay = '${timeSinceStart.inMinutes}m ${timeSinceStart.inSeconds % 60}s';
                             
                             return ListTile(
                                leading: Icon(status['cheatingCount'] > 0 ? Icons.error : Icons.person_outline, color: status['cheatingCount'] > 0 ? Colors.red : Colors.blue),
                                title: Text(status['userName']),
                                subtitle: Text('Status: ${status['status']} | Progress: ${status['progress']} | Waktu Aktif: $timeDisplay'),
                                trailing: Text('Pelanggaran: ${status['cheatingCount']}', style: TextStyle(color: status['cheatingCount'] > 0 ? Colors.red : Colors.grey)),
                             );
                          }).toList(),
                        ],
                      ),
                    ),
                    
                    // --- Laporan Hasil ---
                    ListTile(
                      title: const Text('Lihat Hasil & Laporan'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Tampilkan detail hasil
                        showDialog(context: context, builder: (ctx) => _buildResultDetail(ctx, exam, examResults, controller));
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultDetail(BuildContext context, Exam exam, List<ExamResult> results, AppController controller) {
    return AlertDialog(
      title: Text('Hasil Ujian: ${exam.title}'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Peserta: ${results.length}'),
              const Divider(),
              if (results.isEmpty) const Text('Belum ada siswa yang mengerjakan ujian ini.'),
              ...results.map((r) {
                final logs = controller.getStudentCheatingLogs(r.userId);
                return ListTile(
                  title: Text(r.userName),
                  subtitle: Text('Skor: ${r.score} | Waktu: ${r.timeTaken.inMinutes}m ${r.timeTaken.inSeconds % 60}s'),
                  trailing: Text('Pelanggaran: ${r.cheatingCount} kali', style: TextStyle(color: r.cheatingCount > 0 ? Colors.red : Colors.green)),
                  onTap: () {
                    showDialog(context: context, builder: (ctx) => _buildCheatingLog(ctx, r, logs));
                  },
                );
              }).toList(),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup'))],
    );
  }
  
  Widget _buildCheatingLog(BuildContext context, ExamResult result, List<CheatingLog> logs) {
    return AlertDialog(
      title: Text('Detail Pelanggaran ${result.userName}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Skor Akhir: ${result.score} | Pelanggaran Total: ${result.cheatingCount}'),
              const Divider(),
              if (logs.isEmpty) const Text('Tidak ada pelanggaran tercatat.'),
              ...logs.map((log) => ListTile(
                title: Text(log.type),
                subtitle: Text(log.description),
                trailing: Text('${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}'),
              )).toList(),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup'))],
    );
  }
  
  Widget _buildGlobalCheatingReport(BuildContext context, List<CheatingLog> logs) {
    // Urutkan berdasarkan waktu terbaru
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return AlertDialog(
      title: const Text('🚨 Laporan Kecurangan Global'),
      content: SizedBox(
        width: 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Pelanggaran Tercatat: ${logs.length}'),
            const Divider(),
            SizedBox(
              height: 400,
              width: double.infinity,
              child: logs.isEmpty 
                ? const Center(child: Text('Tidak ada log kecurangan yang tercatat.'))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.report_problem, color: Colors.orange),
                          title: Text('[${log.type}] Siswa ID: ${log.userId}'),
                          subtitle: Text(log.description),
                          trailing: Text('${log.timestamp.day}/${log.timestamp.month} ${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}'),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup'))],
    );
  }
}

// --- CreateExamPage (BAGIAN 3) ---
class CreateExamPage extends StatefulWidget {
  const CreateExamPage({super.key});

  @override
  State<CreateExamPage> createState() => _CreateExamPageState();
}

class _CreateExamPageState extends State<CreateExamPage> {
  final _examFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _promptController = TextEditingController(text: 'Buat 5 soal pilihan ganda matematika topik persamaan linear');
  
  // PERPANJANGAN: Controller Batas Waktu
  DateTime? _selectedStartTime;
  DateTime? _selectedEndTime;
  
  List<Question> _questions = [];
  bool _isLoading = false;

  void _generate(AppController controller) async {
    if (!_examFormKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _questions = [];
    });
    
    await Future.delayed(const Duration(seconds: 1)); // Simulasi API latency
    final generated = generateQuestions(_promptController.text);

    setState(() {
      _questions = generated;
      _isLoading = false;
    });
  }
  
  void _saveExam(AppController controller) {
    if (!_examFormKey.currentState!.validate()) return;
    
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buat soal terlebih dahulu.')));
      return;
    }
    
    controller.createNewExam(
      title: _titleController.text,
      durationMinutes: int.tryParse(_durationController.text) ?? 60,
      questions: _questions,
      startTime: _selectedStartTime,
      endTime: _selectedEndTime,
    );
  }
  
  Future<void> _selectTime(bool isStart) async {
    final DateTime now = DateTime.now();
    
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _selectedStartTime ?? now : _selectedEndTime ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    
    if (selectedDate == null) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _selectedStartTime ?? now : _selectedEndTime ?? now),
    );
    
    if (selectedTime != null) {
      final finalDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
      setState(() {
        if (isStart) {
          _selectedStartTime = finalDateTime;
        } else {
          _selectedEndTime = finalDateTime;
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final controller = ChangeNotifierProvider.of(context, listen: false);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Ujian Baru'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => controller._navigateTo(AppState.dashboard)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _examFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⚙️ Detail Ujian', style: Theme.of(context).textTheme.headlineSmall),
              TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Judul Ujian'), validator: (v) => v!.isEmpty ? 'Judul wajib diisi' : null),
              TextFormField(
                controller: _durationController, 
                decoration: const InputDecoration(labelText: 'Durasi (Menit)', suffixText: 'Menit'), 
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v!) == null || int.parse(v) <= 0 ? 'Durasi harus angka positif' : null,
              ),
              const SizedBox(height: 20),
              
              Text('⏱️ Batas Waktu Ujian (Opsional)', style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Waktu Mulai'),
                      child: TextButton(
                        onPressed: () => _selectTime(true),
                        child: Text(_selectedStartTime == null ? 'Pilih Waktu' : '${_selectedStartTime!.day}/${_selectedStartTime!.month} ${_selectedStartTime!.hour.toString().padLeft(2, '0')}:${_selectedStartTime!.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Waktu Berakhir'),
                      child: TextButton(
                        onPressed: () => _selectTime(false),
                        child: Text(_selectedEndTime == null ? 'Pilih Waktu' : '${_selectedEndTime!.day}/${_selectedEndTime!.month} ${_selectedEndTime!.hour.toString().padLeft(2, '0')}:${_selectedEndTime!.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),

              Text('🤖 Generator Soal AI', style: Theme.of(context).textTheme.headlineSmall),
              TextFormField(
                controller: _promptController,
                decoration: InputDecoration(
                  labelText: 'Prompt AI (cth: Buat 5 soal pilihan ganda matematika topik persamaan linear)',
                  suffixIcon: _isLoading ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _generate(controller)),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 20),

              Text('📜 Preview Soal (${_questions.length} Soal)', style: Theme.of(context).textTheme.headlineSmall),
              if (_questions.isEmpty) const Text('Belum ada soal. Gunakan generator AI atau unggah secara manual.'),
              ..._questions.map((q) => ListTile(
                title: Text(q.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Jawaban Kunci: ${q.correctAnswer}'),
              )).toList(),
              const SizedBox(height: 30),
              
              ElevatedButton.icon(
                onPressed: _questions.isNotEmpty && !_isLoading ? () => _saveExam(controller) : null,
                icon: const Icon(Icons.save),
                label: const Text('Simpan & Publikasikan Ujian'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- StudentExamPage (BAGIAN 4 & 5) ---
class StudentExamPage extends StatefulWidget {
  final Exam exam;
  const StudentExamPage({super.key, required this.exam});

  @override
  State<StudentExamPage> createState() => _StudentExamPageState();
}

class _StudentExamPageState extends State<StudentExamPage> with WidgetsBindingObserver {
  late int _remainingSeconds;
  Timer? _timer;
  int _currentPage = 0;
  
  // Anti-kecurangan (Fokus Web)
  Timer? _focusLostTimer;
  bool _isFocusLost = false;
  final int _maxFocusLoss = 3; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = widget.exam.durationMinutes * 60;
    _startTimer();
    
    // Mencegah klik kanan
    SystemChannels.keyboard.addHandler(_handleKeyEvent);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _focusLostTimer?.cancel();
    SystemChannels.keyboard.removeHandler(_handleKeyEvent);
    super.dispose();
  }
  
  bool _handleKeyEvent(ByteData data) {
    // Deteksi Right Click (Mouse Secondary Button) - tidak sempurna di semua platform
    final controller = ChangeNotifierProvider.of(context, listen: false);
    
    // Cek apakah tombol konteks menu ditekan (seringkali muncul saat klik kanan)
    if (data.lengthInBytes >= 8) {
      final keyEvent = LogicalKeySet.fromMap(data.buffer.asByteData().asMap());
      if (keyEvent.keys.contains(LogicalKeyboardKey.contextMenu) || keyEvent.keys.contains(LogicalKeyboardKey.select)) {
        controller.incrementCheatingCounter('MOUSE_ACTION', 'Klik Kanan (Context Menu) terdeteksi.');
        return true; // Menghambat event
      }
    }
    return false;
  }

  // Deteksi Kehilangan Fokus
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ChangeNotifierProvider.of(context, listen: false);
    if (controller.currentState != AppState.examActive) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_isFocusLost) {
        _isFocusLost = true;
        controller.incrementCheatingCounter('FOCUS_LOST', 'Kehilangan fokus terdeteksi. Mulai hitungan 3 detik...');
        
        _focusLostTimer = Timer(const Duration(seconds: 3), () {
          if (_isFocusLost) {
            // Jika melebihi 3 detik dan fokus masih hilang, trigger finishExam jika batas tercapai
            if (controller.cheatingCounter >= _maxFocusLoss) {
                controller.finishExam(isAutomatic: true);
            }
          }
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      _focusLostTimer?.cancel();
      _isFocusLost = false;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        // Auto-submit jika waktu habis
        ChangeNotifierProvider.of(context, listen: false).finishExam(isAutomatic: true);
      }
    });
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChangeNotifierProvider.of(context);
    final question = widget.exam.questions[_currentPage];
    final currentAnswer = controller.studentAnswers[question.id];
    final progress = (_currentPage + 1) / widget.exam.questions.length;

    return PopScope(
      canPop: false, // Blokir tombol kembali browser/HP
      child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(value: progress, minHeight: 8),
            
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Waktu: ${_formatTime(_remainingSeconds)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: _remainingSeconds <= 60 ? Colors.red : Theme.of(context).colorScheme.onErrorContainer)),
                  Text('Pelanggaran: ${controller.cheatingCounter}/${_maxFocusLoss}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: ListView(
                  children: [
                    Text('Soal ${_currentPage + 1} dari ${widget.exam.questions.length}', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    
                    Text(question.text, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 20),

                    // Opsi Jawaban (Gunakan shuffledOptions)
                    ...question.shuffledOptions.entries.map((entry) {
                      final optionChar = entry.key; // A, B, C, D (dari map)
                      final optionText = entry.value; // Teks opsi yang sudah diacak
                      final isSelected = currentAnswer == optionChar;

                      return Card(
                        color: isSelected ? Theme.of(context).colorScheme.secondaryContainer : null,
                        child: ListTile(
                          title: Text('$optionChar. $optionText'),
                          leading: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked),
                          onTap: () => controller.submitAnswer(question.id, optionChar),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            // Navigasi
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Sebelumnya'),
                  ),
                  if (_currentPage < widget.exam.questions.length - 1)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _currentPage++),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Berikutnya'),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => controller.finishExam(isAutomatic: false),
                      icon: const Icon(Icons.send),
                      label: const Text('Kirim Jawaban'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

// --- ResultReportPage (BAGIAN 6) ---
class ResultReportPage extends StatelessWidget {
  const ResultReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChangeNotifierProvider.of(context);
    final result = controller.lastSubmittedResult!; 
    final activeExam = controller.activeExam!;

    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Ujian Anda'), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('🎉 Ujian Selesai!', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 20),
                  Text('Skor Akhir', style: Theme.of(context).textTheme.titleLarge),
                  Text(result.score.toString(), style: Theme.of(context).textTheme.displayLarge?.copyWith(color: result.score >= 70 ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('Total Soal: ${activeExam.questions.length}'),
                  Text('Jawaban Benar: ${(result.score / 100 * activeExam.questions.length).round()} dari ${activeExam.questions.length}', style: Theme.of(context).textTheme.titleMedium),
                  Text('Waktu Pengerjaan: ${result.timeTaken.inMinutes} Menit ${result.timeTaken.inSeconds % 60} Detik', style: Theme.of(context).textTheme.titleSmall),
                  Text('Pelanggaran Tercatat: ${result.cheatingCount} kali', style: TextStyle(color: result.cheatingCount > 0 ? Colors.red : Colors.green)),
                  const Divider(height: 40),
                  
                  // Tombol Tinjau Jawaban
                  ElevatedButton.icon(
                    onPressed: controller.goToReviewResult,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Tinjau Jawaban (Lihat Kunci)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: controller.logout,
                    child: const Text('Selesai & Keluar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- ReviewResultPage (Tinjauan Jawaban) ---
class ReviewResultPage extends StatelessWidget {
  const ReviewResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChangeNotifierProvider.of(context);
    final exam = controller.activeExam!;
    final result = controller.lastSubmittedResult!; 

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tinjauan Jawaban Ujian'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: controller.finishReviewAndLogout),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: exam.questions.length,
        itemBuilder: (context, index) {
          final question = exam.questions[index];
          final studentAnswer = result.answers[question.id];
          final isCorrect = studentAnswer == question.correctAnswer;
          
          Color cardColor = isCorrect ? Colors.green.shade50 : Colors.red.shade50;
          Color iconColor = isCorrect ? Colors.green : Colors.red;

          return Card(
            color: cardColor,
            margin: const EdgeInsets.only(bottom: 15),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Soal ${index + 1}', style: Theme.of(context).textTheme.titleMedium),
                  const Divider(),
                  Text(question.text, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  
                  // Tampilkan Opsi dan Penandaan Jawaban
                  ...question.shuffledOptions.entries.map((entry) {
                    final optionChar = entry.key;
                    final optionText = entry.value;
                    final isStudentChoice = studentAnswer == optionChar;
                    final isCorrectAnswer = question.correctAnswer == optionChar;
                    
                    IconData optionIcon = Icons.radio_button_unchecked;
                    Color textColor = Colors.black;
                    FontWeight fontWeight = FontWeight.normal;
                    
                    // Sesuaikan warna teks berdasarkan Mode Gelap/Terang
                    if (Theme.of(context).brightness == Brightness.dark) {
                      textColor = Colors.white70;
                    } else {
                      textColor = Colors.black;
                    }

                    if (isCorrectAnswer) {
                      optionIcon = Icons.check_circle_outline;
                      textColor = Colors.green.shade800;
                      fontWeight = FontWeight.bold;
                    }
                    if (isStudentChoice && !isCorrectAnswer) {
                      optionIcon = Icons.highlight_off;
                      textColor = Colors.red.shade800;
                      fontWeight = FontWeight.bold;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Icon(optionIcon, color: textColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('$optionChar. $optionText', style: TextStyle(color: textColor, fontWeight: fontWeight))),
                        ],
                      ),
                    );
                  }).toList(),
                  
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: iconColor),
                      const SizedBox(width: 8),
                      Text(
                        isCorrect ? 'Jawaban Anda Benar!' : 'Jawaban Anda Salah.',
                        style: TextStyle(color: iconColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.finishReviewAndLogout,
        label: const Text('Selesai Tinjauan & Keluar'),
        icon: const Icon(Icons.exit_to_app),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }
}
// main.dart (Bagian yang Diperbarui)

// ... (Model, Database, Controller/Mixin tetap sama)

// =============================================================================
// BARU: DEFINISI SKEMA WARNA KHUSUS (High Contrast Exam Theme)
// =============================================================================

final ColorScheme examColorScheme = ColorScheme.fromSeed(
  seedColor: Colors.blueAccent,
  brightness: Brightness.light,
  primary: const Color(0xFF0044AA), // Biru gelap untuk header
  secondary: const Color(0xFFFFA500), // Orange untuk aksi/ragu-ragu
  error: const Color(0xFFB00020), // Merah kuat untuk bahaya/pelanggaran
  background: const Color(0xFFFAFAFA), // Latar belakang sangat terang
  surface: Colors.white,
  onPrimary: Colors.white,
  onError: Colors.white,
  // Kontras tinggi untuk teks
  onSurface: Colors.black87, 
  onBackground: Colors.black87,
);

// Tema kustom untuk siswa
final ThemeData examTheme = ThemeData(
  colorScheme: examColorScheme,
  useMaterial3: true,
  // Font yang jelas dan mudah dibaca
  fontFamily: 'Roboto', 
  // Peningkatan kontras untuk Card (opsi jawaban)
  cardTheme: CardTheme(
    elevation: 2,
    margin: const EdgeInsets.symmetric(vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: Colors.grey.shade300, width: 1.0),
    ),
  ),
  // Peningkatan kontras untuk tombol
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: examColorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  ),
);

// =============================================================================
// MAIN APP (Update ThemeData dan ThemeMode)
// =============================================================================

class OnlineExamApp extends StatelessWidget {
  const OnlineExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChangeNotifierProvider.of(context);
    final isStudent = controller.currentUser?.role == UserRole.siswa || controller.currentState == AppState.examActive;

    // Siswa menggunakan tema kustom kontras tinggi (examTheme)
    final studentTheme = examTheme;
    // Guru/Default menggunakan tema Material standar
    final defaultTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      useMaterial3: true,
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Pro-Exam Pro (Anti-Cheating)',
      // Tema Terang untuk Guru/Default
      theme: defaultTheme, 
      // Tema Gelap standar
      darkTheme: ThemeData.dark(useMaterial3: true), 
      // Terapkan tema ujian jika siswa sedang aktif
      themeMode: isStudent ? ThemeMode.light : ThemeMode.system, 
      home: Theme(
        // Inject tema ujian ke dalam Widget tree saat ujian aktif
        data: isStudent ? studentTheme : defaultTheme,
        child: const MainRouter(),
      ),
    );
  }
}


// =============================================================================
// STUDENT EXAM PAGE (Penerapan Warna Kontras Kritis)
// =============================================================================

class StudentExamPage extends StatefulWidget {
  // ... (Kelas tetap sama)
}

class _StudentExamPageState extends State<StudentExamPage> with WidgetsBindingObserver {
  // ... (State & Logika tetap sama)

  @override
  Widget build(BuildContext context) {
    final controller = ChangeNotifierProvider.of(context);
    final question = widget.exam.questions[_currentPage];
    final currentAnswer = controller.studentAnswers[question.id];
    final progress = (_currentPage + 1) / widget.exam.questions.length;
    final isTimeCritical = _remainingSeconds <= 300; // 5 Menit

    return PopScope(
      canPop: false,
      child: Column(
        children: [
          // BARU: Progress Bar Kontras
          LinearProgressIndicator(
            value: progress, 
            minHeight: 10,
            color: context.read<AppController>().cheatingCounter > 0 ? Colors.red : Colors.green, // Indikasi status keseluruhan
            backgroundColor: Colors.grey.shade300,
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            color: isTimeCritical ? const Color(0xFFFFE0B2) : Theme.of(context).colorScheme.surface, // Kuning Muda saat kritis
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // BARU: Timer Kontras Tinggi
                Text(
                  'Waktu Tersisa: ${_formatTime(_remainingSeconds)}', 
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isTimeCritical ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface, 
                    fontWeight: FontWeight.bold
                  )
                ),
                // BARU: Pelanggaran Kontras Tinggi
                Text(
                  '🚨 Pelanggaran: ${controller.cheatingCounter}/${controller.maxCheatingCount}', 
                  style: TextStyle(
                    color: controller.cheatingCounter > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface, 
                    fontWeight: FontWeight.bold
                  )
                ),
              ],
            ),
          ),
          
          Expanded(
            // ... (Bagian konten soal tetap sama)
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Soal ${_currentPage + 1} dari ${widget.exam.questions.length}', style: Theme.of(context).textTheme.titleMedium),
                  const Divider(),
                  
                  // Text Soal dengan kontras tinggi
                  Text(question.text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onBackground)),
                  const SizedBox(height: 20),

                  // Opsi Jawaban (Card)
                  ...question.options.map((option) {
                    final optionIndex = question.options.indexOf(option);
                    final optionChar = String.fromCharCode('A'.codeUnitAt(0) + optionIndex);
                    final isSelected = currentAnswer == optionChar;

                    return Card(
                      color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Theme.of(context).colorScheme.surface,
                      // BARU: Border tebal pada opsi yang dipilih
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300, 
                          width: isSelected ? 2.5 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        title: Text('$optionChar. $option', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        leading: Icon(
                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked, 
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                        ),
                        onTap: () => controller.submitAnswer(question.id, optionChar),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          // ... (Bagian tombol navigasi tetap sama)
        ],
      ),
    );
  }
}

// Tambahkan extension untuk mudah membaca AppController di build
extension ContextExtension on BuildContext {
  T read<T extends ChangeNotifier>() {
    return ChangeNotifierProvider.of(this);
  }
}
