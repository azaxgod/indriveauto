import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Для проверки платформы

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализируем сервис фона только если не веб
  if (!kIsWeb) {
    await initializeBackgroundService();
  }

  runApp(const MyApp());
}

const platform = MethodChannel('autoclick_channel');

// Инициализация фонового сервиса (только для мобильных платформ)
Future<void> initializeBackgroundService() async {
  if (kIsWeb) {
    return; // Пропускаем настройку фона для Web
  }

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundTask,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
    ),
  );
}

void backgroundTask(ServiceInstance service) async {
  if (kIsWeb) {
    return; // Пропускаем фоновую задачу для Web
  }

  int updateInterval = 1000;
  int clickInterval = 1000;

  service.on('setUpdateInterval').listen((event) {
    updateInterval = event?['interval'];
  });

  service.on('setClickInterval').listen((event) {
    clickInterval = event?['interval'];
  });

  while (true) {
    await Future.delayed(Duration(milliseconds: updateInterval));
    service.invoke('setData', {
      "message": "Фоновая задача работает ${DateTime.now()}."
    });

    await Future.delayed(Duration(milliseconds: clickInterval));
    service.invoke('clickAction', {
      "action": "click"
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideIn = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AutoClickerSettings()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          children: [
            const Spacer(),
            FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: const Text(
                  'Welcome to Auto Clicker',
                  style: TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Text(
                "Development by Aza Molodoy Boss",
                style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AutoClickerSettings extends StatefulWidget {
  const AutoClickerSettings({super.key});

  @override
  State<AutoClickerSettings> createState() => _AutoClickerSettingsState();
}

class _AutoClickerSettingsState extends State<AutoClickerSettings> {
  final TextEditingController _priceController = TextEditingController();
  bool _isEditing = false;
  bool _isAutoClickerRunning = false;
  bool _isLoading = false;

  String _savedPrice = "";
  double _clickInterval = 1000.0;
  double _screenUpdateInterval = 1000.0; // Новый параметр для обновления экрана

  @override
  void initState() {
    super.initState();
    _loadSavedPrice();
    _checkAutoClickerStatus();
  }

  Future<void> _loadSavedPrice() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPrice = prefs.getString('target_price') ?? "";
      _priceController.text = _savedPrice;
    });
  }

  Future<void> _savePrice() async {
    if (_priceController.text.isNotEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('target_price', _priceController.text);
      setState(() {
        _savedPrice = _priceController.text;
        _isEditing = false;
      });
    }
  }

  Future<void> _checkAutoClickerStatus() async {
    try {
      final isRunning = await platform.invokeMethod('isAutoClickerRunning');
      setState(() {
        _isAutoClickerRunning = isRunning;
      });
    } catch (e) {
      print("Error checking status: $e");
    }
  }

  Future<void> _startAutoClicker() async {
    if (_savedPrice.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a target price."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await platform.invokeMethod('startAutoClicker', {
        'price': _savedPrice,
        'clickInterval': _clickInterval.toInt(),
        'swipeInterval': 2000,
        'screenUpdateInterval': _screenUpdateInterval.toInt(), // Передаем новый параметр
      });

      // Проверяем, заработал ли автокликер
      final isRunning = await platform.invokeMethod('isAutoClickerRunning');
      if (isRunning == true) {
        setState(() {
          _isAutoClickerRunning = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("AutoClicker успешно запущен ✅"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ошибка запуска AutoClicker ❌"), backgroundColor: Colors.red),
        );
        debugPrint("AutoClicker: сервис не стартовал. Причина неизвестна.");
      }
    } catch (e, stackTrace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось запустить автокликер ❌"), backgroundColor: Colors.red),
      );
      // В лог для разработчика подробная ошибка
      debugPrint("Ошибка запуска AutoClicker: $e\nСтек вызовов:\n$stackTrace");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _stopAutoClicker() async {
    try {
      await platform.invokeMethod('stopAutoClicker');
      setState(() {
        _isAutoClickerRunning = false;
      });
    } catch (e) {
      print("Error stopping auto clicker: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto Clicker Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 5,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Target Price'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!_isEditing)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          setState(() => _isEditing = true);
                        },
                      )
                    else
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.save),
                            onPressed: _savePrice,
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: () {
                              setState(() {
                                _priceController.text = _savedPrice;
                                _isEditing = false;
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 5,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Click Interval (ms)', style: TextStyle(fontSize: 16)),
                    Slider(
                      value: _clickInterval,
                      min: 500,
                      max: 5000,
                      divisions: 9,
                      onChanged: (value) {
                        setState(() {
                          _clickInterval = value;
                        });
                      },
                    ),
                    Text('${_clickInterval.toInt()} ms', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 5,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Screen Update Interval (ms)', style: TextStyle(fontSize: 16)),
                    Slider(
                      value: _screenUpdateInterval,
                      min: 500,
                      max: 5000,
                      divisions: 9,
                      onChanged: (value) {
                        setState(() {
                          _screenUpdateInterval = value;
                        });
                      },
                    ),
                    Text('${_screenUpdateInterval.toInt()} ms', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: _isAutoClickerRunning ? null : _startAutoClicker,
                        child: const Text('Start Auto Clicker'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isAutoClickerRunning ? _stopAutoClicker : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Stop Auto Clicker'),
                      ),
                    ],
                  ),
            const Spacer(),
            const Text(
              "Development by Aza Molodoy Boss",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
