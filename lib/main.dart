import 'package:flutter/material.dart';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

void main() {
  runApp(const ServiceInspectorApp());
}

class ServiceInspectorApp extends StatelessWidget {
  const ServiceInspectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فحص الخدمة والراوترات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const MainInspectorScreen(),
    );
  }
}

class MainInspectorScreen extends StatefulWidget {
  const MainInspectorScreen({super.key});

  @override
  State<MainInspectorScreen> createState() => _MainInspectorScreenState();
}

class _MainInspectorScreenState extends State<MainInspectorScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فحص الخدمة والراوترات', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.network_check), text: 'فحص الاتصال'),
              Tab(icon: Icon(Icons.router), text: 'فحص SSH'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            NetworkTestTab(),
            RouterSshTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------- 1. تبويب فحص الإنترنت والـ Ping ----------------
class NetworkTestTab extends StatefulWidget {
  const NetworkTestTab({super.key});

  @override
  State<NetworkTestTab> createState() => _NetworkTestTabState();
}

class _NetworkTestTabState extends State<NetworkTestTab> {
  final List<Map<String, String>> _targets = [
    {'name': 'Google DNS', 'ip': '8.8.8.8'},
    {'name': 'Cloudflare DNS', 'ip': '1.1.1.1'},
    {'name': 'الراوتر / Gateway', 'ip': '192.168.1.1'},
  ];

  final Map<String, String> _results = {};
  bool _isTesting = false;

  Future<void> _runPingTests() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    for (var target in _targets) {
      final ip = target['ip']!;
      try {
        final result = await Process.run('ping', ['-c', '2', '-w', '2', ip]);
        if (result.exitCode == 0) {
          _results[ip] = 'متصل (OK)';
        } else {
          _results[ip] = 'غير متصل (Timeout)';
        }
      } catch (e) {
        _results[ip] = 'خطأ بالفحص';
      }
      setState(() {});
    }

    setState(() {
      _isTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _isTesting ? null : _runPingTests,
            icon: _isTesting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Icon(Icons.play_arrow),
            label: Text(_isTesting ? 'جاري الفحص...' : 'بدء فحص الشبكة'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _targets.length,
              itemBuilder: (context, index) {
                final item = _targets[index];
                final status = _results[item['ip']] ?? 'لم يتم الفحص';
                final isOk = status.contains('OK');

                return Card(
                  child: ListTile(
                    leading: Icon(
                      isOk ? Icons.check_circle : Icons.error_outline,
                      color: isOk ? Colors.green : Colors.grey,
                    ),
                    title: Text(item['name']!),
                    subtitle: Text('IP: ${item['ip']}'),
                    trailing: Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOk ? Colors.green : Colors.red,
                      ),
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

// ---------------- 2. تبويب فحص الراوتر عبر SSH ----------------
class RouterSshTab extends StatefulWidget {
  const RouterSshTab({super.key});

  @override
  State<RouterSshTab> createState() => _RouterSshTabState();
}

class _RouterSshTabState extends State<RouterSshTab> {
  final _ipController = TextEditingController(text: '192.168.88.1');
  final _userController = TextEditingController(text: 'admin');
  final _passController = TextEditingController();
  
  String _logs = 'أدخل بيانات الراوتر واضغط فحص الاتصال...';
  bool _isLoading = false;

  Future<void> _testRouterConnection() async {
    setState(() {
      _isLoading = true;
      _logs = 'جاري الاتصال بـ ${_ipController.text}...';
    });

    try {
      final socket = await SSHSocket.connect(_ipController.text, 22, timeout: const Duration(seconds: 5));
      final client = SSHClient(
        socket,
        username: _userController.text,
        onPasswordRequest: () => _passController.text,
      );

      final result = await client.run('system resource print');
      setState(() {
        _logs = 'تم الاتصال بنجاح!\n\nمعلومات الجهاز:\n${String.fromCharCodes(result)}';
      });
      client.close();
    } catch (e) {
      setState(() {
        _logs = 'فشل الاتصال بالراوتر!\nالسبب: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: 'IP الراوتر', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: 'اسم المستخدم', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة السر', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _isLoading ? null : _testRouterConnection,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('فحص حالة الراوتر'),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _logs,
                style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
