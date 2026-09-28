import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const MaterialApp(
    home: MainTabScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class MainTabScreen extends StatelessWidget {
  const MainTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Network Tools'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.wifi_tethering), text: 'إدارة السكاتر'),
              Tab(icon: Icon(Icons.router), text: 'فحص الراوتر'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            UbntApp(),
            RouterDiagnosticScreen(),
          ],
        ),
      ),
    );
  }
}

// ------------------- شاشة فحص الراوتر والتقرير -------------------
class RouterDiagnosticScreen extends StatefulWidget {
  const RouterDiagnosticScreen({super.key});

  @override
  State<RouterDiagnosticScreen> createState() => _RouterDiagnosticScreenState();
}

class _RouterDiagnosticScreenState extends State<RouterDiagnosticScreen> {
  final TextEditingController _ipController = TextEditingController(text: '192.168.88.1');
  final TextEditingController _userController = TextEditingController(text: 'admin');
  final TextEditingController _passController = TextEditingController(text: '');
  
  String _selectedType = 'Mikrotik';
  bool _isLoading = false;
  Map<String, dynamic>? _diagnosticReport;

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _diagnosticReport = null;
    });

    final String ip = _ipController.text.trim();
    final String user = _userController.text.trim();
    final String pass = _passController.text;

    if (_selectedType == 'Mikrotik') {
      await _diagnoseMikrotik(ip, user, pass);
    } else {
      await _diagnoseHomeRouter(ip);
    }

    setState(() {
      _isLoading = false;
    });
  }

  // فحص الميكروتك عبر SSH
  Future<void> _diagnoseMikrotik(String ip, String user, String pass) async {
    int score = 100;
    List<String> issues = [];
    List<String> statusDetails = [];

    try {
      final socket = await SSHSocket.connect(ip, 22, timeout: const Duration(seconds: 5));
      final client = SSHClient(socket, username: user, onPasswordRequest: () => pass);

      // 1. فحص الموارد
      final resResult = await client.run('/system resource print');
      final resText = String.fromCharCodes(resResult);
      
      int cpuLoad = 0;
      final cpuMatch = RegExp(r'cpu-load:\s*(\d+)%').firstMatch(resText);
      if (cpuMatch != null) {
        cpuLoad = int.parse(cpuMatch.group(1)!);
      }

      if (cpuLoad > 85) {
        score -= 30;
        issues.add('استهلاك المعالج مرتفع جداً ($cpuLoad%) - الجهاز مضغوط');
      } else {
        statusDetails.add('المعالج يعمل بشكل طبيعي ($cpuLoad%)');
      }

      // 2. فحص الهيلث (فولتية وحرارة ان وجدت)
      try {
        final healthResult = await client.run('/system health print');
        final healthText = String.fromCharCodes(healthResult);
        if (healthText.contains('voltage')) {
          statusDetails.add('قراءات الفولتية والحرارة سليمة');
        }
      } catch (_) {}

      // 3. فحص الأخطاء بـ Interfaces
      final intfResult = await client.run('/interface print stats');
      final intfText = String.fromCharCodes(intfResult);
      if (intfText.contains('drop') || intfText.contains('error')) {
        // فحص تقريبي للأخطاء
        if (RegExp(r'rx-drop:\s*([1-9]\d*)').hasMatch(intfText)) {
          score -= 20;
          issues.add('تم كشف أخطاء Drop على البورتات - افحص الفيشة والكيبل');
        }
      }

      client.close();

      _buildReport('Mikrotik RouterOS', score, issues, statusDetails);

    } catch (e) {
      _buildReport('Mikrotik RouterOS', 0, ['فشل الاتصال بالراوتر عبر SSH: $e'], []);
    }
  }

  // فحص راوترات المنازل (TP-Link / Cudy / Tenda)
  Future<void> _diagnoseHomeRouter(String ip) async {
    int score = 100;
    List<String> issues = [];
    List<String> statusDetails = [];

    try {
      // 1. فحص الوصول إلى صفحة الويب
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('http://$ip'));
      final response = await request.close();

      statusDetails.add('استجابة صفحة الإدارة HTTP: OK (${response.statusCode})');

      // 2. قياس الـ Latency والـ Stability
      int totalMs = 0;
      int successCount = 0;
      for (int i = 0; i < 5; i++) {
        final stopwatch = Stopwatch()..start();
        try {
          final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 2));
          socket.destroy();
          stopwatch.stop();
          totalMs += stopwatch.elapsedMilliseconds;
          successCount++;
        } catch (_) {}
      }

      if (successCount < 5) {
        score -= 40;
        issues.add('توجد باكتات مفقودة (Packet Loss) بينك وبين الراوتر');
      } else {
        int avgPing = totalMs ~/ successCount;
        statusDetails.add('معدل الاستجابة المحلي: $avgPing ms');
        if (avgPing > 20) {
          score -= 15;
          issues.add('استجابة الراوتر بطيئة نوعاً ما ($avgPing ms)');
        }
      }

      _buildReport('Home Router ($_selectedType)', score, issues, statusDetails);

    } catch (e) {
      _buildReport('Home Router ($_selectedType)', 0, ['تعذر الوصول للراوتر على IP: $ip'], []);
    }
  }

  void _buildReport(String device, int score, List<String> issues, List<String> statusDetails) {
    String rating = 'ممتاز';
    Color color = Colors.green;

    if (score < 50) {
      rating = 'سيء جداً / يحتاج صيانة';
      color = Colors.red;
    } else if (score < 80) {
      rating = 'متوسط / يوجد تنبيهات';
      color = Colors.orange;
    }

    _diagnosticReport = {
      'device': device,
      'score': score < 0 ? 0 : score,
      'rating': rating,
      'color': color,
      'issues': issues,
      'statusDetails': statusDetails,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(labelText: 'نوع الراوتر'),
                    items: ['Mikrotik', 'TP-Link / Cudy / Tenda']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedType = val!),
                  ),
                  TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(labelText: 'IP الراوتر'),
                  ),
                  if (_selectedType == 'Mikrotik') ...[
                    TextField(
                      controller: _userController,
                      decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                    ),
                    TextField(
                      controller: _passController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'كلمة السر'),
                    ),
                  ],
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _runDiagnostics,
                    icon: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.search),
                    label: Text(_isLoading ? 'جاري الفحص...' : 'بدء فحص الراوتر'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          if (_diagnosticReport != null) ...[
            Card(
              color: (_diagnosticReport!['color'] as Color).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'تقرير أداء الراوتر: ${_diagnosticReport!['score']}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _diagnosticReport!['color'],
                      ),
                    ),
                    Text(
                      _diagnosticReport!['rating'],
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Divider(),
                    if ((_diagnosticReport!['issues'] as List).isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('⚠️ المشاكل والتنبيهات:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                      ...(_diagnosticReport!['issues'] as List).map((i) => ListTile(
                            leading: const Icon(Icons.warning, color: Colors.red),
                            title: Text(i),
                          )),
                    ],
                    const SizedBox(height: 10),
                    if ((_diagnosticReport!['statusDetails'] as List).isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('✅ التفاصيل الفنية:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ),
                      ...(_diagnosticReport!['statusDetails'] as List).map((s) => ListTile(
                            leading: const Icon(Icons.check_circle, color: Colors.green),
                            title: Text(s),
                          )),
                    ],
                  ],
                ),
              ),
            )
          ]
        ],
      ),
    );
  }
}

// ------------------- كود السكاتر السابق (UbntApp) -------------------
class SectorModel {
  String ip;
  String username;
  String password;

  SectorModel({required this.ip, required this.username, required this.password});

  Map<String, dynamic> toJson() => {'ip': ip, 'username': username, 'password': password};

  factory SectorModel.fromJson(Map<String, dynamic> json) => SectorModel(
        ip: json['ip'] ?? '',
        username: json['username'] ?? 'ubnt',
        password: json['password'] ?? 'ubnt0.',
      );
}

class UbntApp extends StatefulWidget {
  const UbntApp({super.key});

  @override
  State<UbntApp> createState() => _UbntAppState();
}

class _UbntAppState extends State<UbntApp> {
  List<SectorModel> sectors = [];
  String statusLog = 'جاهز للبدء...';

  @override
  void initState() {
    super.initState();
    _loadSectors();
  }

  Future<void> _loadSectors() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('sectors_data');

    if (savedData != null) {
      final List<dynamic> jsonList = jsonDecode(savedData);
      setState(() {
        sectors = jsonList.map((item) => SectorModel.fromJson(item)).toList();
      });
    } else {
      setState(() {
        sectors = List.generate(
          10,
          (index) => SectorModel(
            ip: '10.181.131.${index + 1}',
            username: 'ubnt',
            password: 'ubnt0.',
          ),
        );
      });
      _saveSectors();
    }
  }

  Future<void> _saveSectors() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(sectors.map((s) => s.toJson()).toList());
    await prefs.setString('sectors_data', encodedData);
  }

  void _showSectorDialog({int? index}) {
    final isEditing = index != null;
    TextEditingController ipController = TextEditingController(text: isEditing ? sectors[index].ip : '10.181.131.');
    TextEditingController userController = TextEditingController(text: isEditing ? sectors[index].username : 'ubnt');
    TextEditingController passController = TextEditingController(text: isEditing ? sectors[index].password : 'ubnt0.');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'تعديل بيانات السكتر' : 'إضافة سكتر جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: ipController, decoration: const InputDecoration(labelText: 'IP السكتر')),
              TextField(controller: userController, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
              TextField(controller: passController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة السر')),
            ],
          ),
        ),
        actions: [
          if (isEditing)
            TextButton(
              onPressed: () {
                setState(() => sectors.removeAt(index));
                _saveSectors();
                Navigator.pop(context);
              },
              child: const Text('حذف السكتر', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (isEditing) {
                  sectors[index].ip = ipController.text;
                  sectors[index].username = userController.text;
                  sectors[index].password = passController.text;
                } else {
                  sectors.add(SectorModel(ip: ipController.text, username: userController.text, password: passController.text));
                }
              });
              _saveSectors();
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> disconnectClients(SectorModel sector) async {
    setState(() => statusLog = 'جاري الاتصال وفصل المشتركين من ${sector.ip}...');
    try {
      final socket = await SSHSocket.connect(sector.ip, 22, timeout: const Duration(seconds: 6));
      final client = SSHClient(socket, username: sector.username, onPasswordRequest: () => sector.password);
      await client.run('ifconfig ath0 down && sleep 1 && ifconfig ath0 up');
      client.close();
      setState(() => statusLog = 'تم فصل جميع المشتركين بنجاح على ${sector.ip}');
    } catch (e) {
      setState(() => statusLog = 'فشل الاتصال بـ ${sector.ip}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text(statusLog, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: sectors.length,
              itemBuilder: (context, index) {
                final sector = sectors[index];
                return Card(
                  child: ListTile(
                    title: Text('IP: ${sector.ip}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('User: ${sector.username}'),
                    leading: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showSectorDialog(index: index)),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                      icon: const Icon(Icons.power_settings_new, size: 18),
                      label: const Text('فصل'),
                      onPressed: () => disconnectClients(sector),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
