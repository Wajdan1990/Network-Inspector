import 'package:flutter/material.dart';
import 'dart:io';

void main() {
  runApp(const ServiceInspectorApp());
}

class ServiceInspectorApp extends StatelessWidget {
  const ServiceInspectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فحص الخدمة والشبكة',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('فحص حالة الخدمة', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
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
      ),
    );
  }
}
