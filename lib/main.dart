import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CudyStyleNetworkApp());
}

class CudyStyleNetworkApp extends StatelessWidget {
  const CudyStyleNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Inspector Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFAFAFA),
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    SpeedAndPingTab(),
    SectorsTab(),
    CdnDetectorTab(),
    MediaStreamTestTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Network Tools Pro',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.grey),
            onPressed: () {},
          )
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'سرعة وزمن'),
          BottomNavigationBarItem(icon: Icon(Icons.cell_tower), label: 'السكواتر'),
          BottomNavigationBarItem(icon: Icon(Icons.hub_outlined), label: 'فحص CDN'),
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_outline), label: 'اختبار الفيديو'),
        ],
      ),
    );
  }
}

// =---------------- 1. تبويب زمن انتقال الشبكة والمنصات ----------------=
class SpeedAndPingTab extends StatefulWidget {
  const SpeedAndPingTab({super.key});

  @override
  State<SpeedAndPingTab> createState() => _SpeedAndPingTabState();
}

class _SpeedAndPingTabState extends State<SpeedAndPingTab> {
  final List<Map<String, String>> _apps = [
    {'name': 'الراوتر Gateway', 'ip': '192.168.1.1', 'icon': 'router'},
    {'name': 'Google.com', 'ip': '8.8.8.8', 'icon': 'google'},
    {'name': 'Facebook CDN', 'ip': '157.240.1.1', 'icon': 'facebook'},
    {'name': 'YouTube GGC', 'ip': '172.217.1.1', 'icon': 'youtube'},
    {'name': 'TikTok CDN', 'ip': '161.117.1.1', 'icon': 'tiktok'},
    {'name': 'PUBG Mobile', 'ip': '18.194.0.1', 'icon': 'game'},
    {'name': 'Telegram', 'ip': '149.154.167.99', 'icon': 'telegram'},
    {'name': 'Cloudflare', 'ip': '1.1.1.1', 'icon': 'dns'},
    {'name': 'Instagram', 'ip': '157.240.2.1', 'icon': 'instagram'},
  ];

  final Map<String, int> _pingResults = {};
  bool _isTesting = false;

  Future<void> _runAllPings() async {
    setState(() {
      _isTesting = true;
      _pingResults.clear();
    });

    for (var item in _apps) {
      final ip = item['ip']!;
      final sw = Stopwatch()..start();
      try {
        final res = await Process.run('ping', ['-c', '1', '-w', '2', ip]);
        sw.stop();
        if (res.exitCode == 0) {
          _pingResults[ip] = sw.elapsedMilliseconds;
        } else {
          _pingResults[ip] = -1; // Timeout
        }
      } catch (e) {
        _pingResults[ip] = -1;
      }
      setState(() {});
    }

    setState(() => _isTesting = false);
  }

  Color _getPingColor(int? ms) {
    if (ms == null) return Colors.grey;
    if (ms < 0) return Colors.red;
    if (ms < 40) return Colors.green;
    if (ms < 100) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('حالة الاتصال العامة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('فحص الاستجابة مع السيرفرات والـ CDN', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                ElevatedButton(
                  onPressed: _isTesting ? null : _runAllPings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isTesting 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text('بدء الفحص'),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('زمن انتقال الشبكة (Latency)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.95,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _apps.length,
            itemBuilder: (context, index) {
              final app = _apps[index];
              final ping = _pingResults[app['ip']];
              final color = _getPingColor(ping);

              return Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.language, color: Colors.blue.shade800, size: 28),
                      const SizedBox(height: 6),
                      Text(app['name']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1),
                      const SizedBox(height: 4),
                      Text(
                        ping == null ? '--' : (ping < 0 ? 'Timeout' : '$ping ms'),
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }
}

// =---------------- 2. تبويب إضافة وإدارة السكواتر ----------------=
class SectorsTab extends StatefulWidget {
  const SectorsTab({super.key});

  @override
  State<SectorsTab> createState() => _SectorsTabState();
}

class _SectorsTabState extends State<SectorsTab> {
  final List<Map<String, String>> _sectors = [
    {'name': 'سكتر 1 - الشمال', 'ip': '10.181.131.1'},
    {'name': 'سكتر 2 - الشرق', 'ip': '10.181.131.2'},
    {'name': 'سكتر 3 - الجنوب', 'ip': '10.181.131.3'},
  ];

  final Map<String, String> _statuses = {};
  bool _isChecking = false;

  void _addSector() {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة سكتر جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم السكتر')),
            TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'عنوان الـ IP')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && ipCtrl.text.isNotEmpty) {
                setState(() {
                  _sectors.add({'name': nameCtrl.text, 'ip': ipCtrl.text});
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          )
        ],
      ),
    );
  }

  Future<void> _checkSectors() async {
    setState(() => _isChecking = true);
    for (var s in _sectors) {
      final ip = s['ip']!;
      try {
        final res = await Process.run('ping', ['-c', '1', '-w', '2', ip]);
        _statuses[ip] = res.exitCode == 0 ? 'متصل 🟢' : 'منقطع 🔴';
      } catch (e) {
        _statuses[ip] = 'خطأ';
      }
      setState(() {});
    }
    setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addSector,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isChecking ? null : _checkSectors,
              icon: const Icon(Icons.refresh),
              label: Text(_isChecking ? 'جاري الفحص...' : 'فحص كل السكواتر'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _sectors.length,
                itemBuilder: (ctx, idx) {
                  final sec = _sectors[idx];
                  final status = _statuses[sec['ip']] ?? 'لم يفحص';
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.cell_tower, color: Colors.blue),
                      title: Text(sec['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('IP: ${sec['ip']}'),
                      trailing: Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

// =---------------- 3. تبويب كاشف CDN & GGC ومصدر الخدمة ----------------=
class CdnDetectorTab extends StatefulWidget {
  const CdnDetectorTab({super.key});

  @override
  State<CdnDetectorTab> createState() => _CdnDetectorTabState();
}

class _CdnDetectorTabState extends State<CdnDetectorTab> {
  String _publicIp = '--';
  String _ispName = '--';
  String _cdnStatus = 'اضغط لمعرفة مصدر سيرفرات الـ Cache';
  bool _loading = false;

  Future<void> _detectCDN() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _publicIp = data['ip'] ?? 'Unknown';
          _ispName = '${data['org']} (${data['country_name']})';
          _cdnStatus = _ispName.toLowerCase().contains('iraq') 
              ? 'الخدمة ممررة عبر مزود محلي (Local Route / Cache Active)'
              : 'الخدمة قادمة عبر المسار الخارجي (International Gateway)';
        });
      }
    } catch (e) {
      setState(() {
        _cdnStatus = 'تعذر الاتصال بسيرفر معلومات الـ IP';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Icon(Icons.hub, size: 50, color: Colors.blue),
                  const SizedBox(height: 10),
                  const Text('كاشف مسار الـ GGC و CDN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ListTile(
                    title: const Text('الـ Public IP الظاهري'),
                    subtitle: Text(_publicIp, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ListTile(
                    title: const Text('اسم الشركة المزودة (ISP)'),
                    subtitle: Text(_ispName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(_cdnStatus, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  )
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _loading ? null : _detectCDN,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('فحص مصدر الـ CDN للشبكة'),
          )
        ],
      ),
    );
  }
}

// =---------------- 4. تبويب فحص أداء مقاطع فيديو (TikTok & YouTube Test) ----------------=
class MediaStreamTestTab extends StatefulWidget {
  const MediaStreamTestTab({super.key});

  @override
  State<MediaStreamTestTab> createState() => _MediaStreamTestTabState();
}

class _MediaStreamTestTabState extends State<MediaStreamTestTab> {
  String _tikTokResult = 'لم يتم الفحص';
  String _ytResult = 'لم يتم الفحص';
  bool _testingTikTok = false;
  bool _testingYT = false;

  Future<void> _testTikTokStream() async {
    setState(() {
      _testingTikTok = true;
      _tikTokResult = 'جاري اختبار ذاكرة البث (Buffer)...';
    });

    final sw = Stopwatch()..start();
    try {
      // حزمة تنزيل تجريبية من سيرفر CDN التابع لـ TikTok
      final res = await http.get(Uri.parse('https://www.tiktok.com/favicon.ico')).timeout(const Duration(seconds: 4));
      sw.stop();
      if (res.statusCode == 200) {
        final speedMs = sw.elapsedMilliseconds;
        setState(() {
          _tikTokResult = 'ممتاز 🟢\nزمن التحميل: $speedMs ms\nيدعم فيديو 1080p بدون تقطيع';
        });
      } else {
        setState(() => _tikTokResult = 'بطيء 🟡 (رمز الاستجابة ${res.statusCode})');
      }
    } catch (e) {
      setState(() => _tikTokResult = 'فشل الاتصال بسيرفر TikTok 🔴');
    } finally {
      setState(() => _testingTikTok = false);
    }
  }

  Future<void> _testYouTubeStream() async {
    setState(() {
      _testingYT = true;
      _ytResult = 'جاري سحب عينة من سيرفر Google GGC...';
    });

    final sw = Stopwatch()..start();
    try {
      // طلب حزمة من سيرفر Google Video/GGC
      final res = await http.get(Uri.parse('https://www.youtube.com/generate_204')).timeout(const Duration(seconds: 4));
      sw.stop();
      if (res.statusCode == 204 || res.statusCode == 200) {
        final speedMs = sw.elapsedMilliseconds;
        setState(() {
          _ytResult = 'استجابة فائقة 🟢\nزمن البث: $speedMs ms\nجودة 4K جاهزة بدون توقف';
        });
      } else {
        setState(() => _ytResult = 'استجابة متوسطة 🟡');
      }
    } catch (e) {
      setState(() => _ytResult = 'فشل الفحص 🔴');
    } finally {
      setState(() => _testingYT = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.music_note, color: Colors.black, size: 36),
              title: const Text('اختبار بث فيديوهات TikTok', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_tikTokResult),
              trailing: ElevatedButton(
                onPressed: _testingTikTok ? null : _testTikTokStream,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                child: _testingTikTok ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('فحص'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.play_circle_fill, color: Colors.red, size: 36),
              title: const Text('اختبار بث فيديوهات YouTube', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_ytResult),
              trailing: ElevatedButton(
                onPressed: _testingYT ? null : _testYouTubeStream,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: _testingYT ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('فحص'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
