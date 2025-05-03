import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();
  runApp(const MyApp());
}

const platform = MethodChannel('autoclick_channel');

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  if (kIsWeb) {
    print("Фоновый сервис не поддерживается на Web.");
    return;
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundTask,
      autoStart: false,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
    ),
  );
}

void backgroundTask(ServiceInstance service) async {
  int updateInterval = 1000; // Default update interval in milliseconds
  int clickInterval = 1000; // Default click interval in milliseconds

  service.on('setUpdateInterval').listen((event) {
    updateInterval = event?['interval'];
  });

  service.on('setClickInterval').listen((event) {
    clickInterval = event?['interval'];
  });

  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  while (true) {
    await Future.delayed(Duration(milliseconds: updateInterval));
    service.invoke('setData', {
      "message": "Фоновая задача работает ${DateTime.now()}."
    });

    // Simulate clicking at the specified clickInterval
    await Future.delayed(Duration(milliseconds: clickInterval));
    service.invoke('clickAction', {
      "action": "click"
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _bottomSlideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeInAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset(0, 0)).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _bottomSlideAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset(0, 0)).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Start the animation
    _animationController.forward();

    // After animation ends, navigate to the main screen
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AutoClickerSettings()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title with fade and slide animation
            FadeTransition(
              opacity: _fadeInAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: const Text(
                  'Welcome to Auto Clicker',
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Spacer(),
            // Development by Aza Molodoy Boss text with bottom slide animation
            SlideTransition(
              position: _bottomSlideAnimation,
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    "Development by Aza Molodoy Boss",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AutoClickerSettings extends StatefulWidget {
  const AutoClickerSettings({Key? key}) : super(key: key);

  @override
  State<AutoClickerSettings> createState() => _AutoClickerSettingsState();
}

class _AutoClickerSettingsState extends State<AutoClickerSettings> with SingleTickerProviderStateMixin {
  final TextEditingController _priceController = TextEditingController();
  bool _isAutoClickerRunning = false;
  bool isEditing = false;
  bool isLoading = false;
  String _savedPrice = "";

  double _updateInterval = 1000.0; // Default update interval (in milliseconds)
  double _clickInterval = 1000.0; // Default click interval (in milliseconds)

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedPrice();
    _checkAutoClickerStatus();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset(0, 0)).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward(); // Start animation when the screen is displayed
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
        isEditing = false;
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      isEditing = false;
      _priceController.text = _savedPrice; // Restore the saved price
    });
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
    setState(() {
      isLoading = true;
    });

    try {
      if (_savedPrice.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please enter a target price."),
          backgroundColor: Colors.red,
        ));
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Set update and click intervals before starting the auto-clicker
      await platform.invokeMethod('setUpdateInterval', {'interval': _updateInterval.toInt()});
      await platform.invokeMethod('setClickInterval', {'interval': _clickInterval.toInt()});

      await platform.invokeMethod('startAutoClicker', {'price': _savedPrice});
      setState(() {
        _isAutoClickerRunning = true;
        isEditing = false;
        isLoading = false;
      });
    } catch (e) {
      print("Error starting auto clicker: $e");
      setState(() {
        isLoading = false;
      });
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
    bool isInputDisabled = _isAutoClickerRunning || isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Auto Clicker"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: AnimatedOpacity(
              opacity: _opacityAnimation.value,
              duration: const Duration(seconds: 2),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _priceController,
                                  decoration: const InputDecoration(
                                    labelText: "Target price",
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  enabled: isEditing && !isInputDisabled,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!isEditing)
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: isInputDisabled
                                      ? null
                                      : () {
                                          setState(() {
                                            isEditing = true;
                                          });
                                        },
                                ),
                              if (isEditing) ...[
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: isInputDisabled ? null : _savePrice,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: isInputDisabled ? null : _cancelEdit,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Slider for update interval
                          const Text("Update Interval (ms)"),
                          Slider(
                            value: _updateInterval,
                            min: 500.0,
                            max: 5000.0,
                            divisions: 9,
                            label: _updateInterval.toStringAsFixed(0),
                            onChanged: isInputDisabled
                                ? null
                                : (value) {
                                    setState(() {
                                      _updateInterval = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 16),

                          // Slider for click interval
                          const Text("Click Interval (ms)"),
                          Slider(
                            value: _clickInterval,
                            min: 500.0,
                            max: 5000.0,
                            divisions: 9,
                            label: _clickInterval.toStringAsFixed(0),
                            onChanged: isInputDisabled
                                ? null
                                : (value) {
                                    setState(() {
                                      _clickInterval = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 24),

                          ElevatedButton(
                            onPressed: isLoading || _isAutoClickerRunning
                                ? null
                                : _startAutoClicker,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text("Start Auto Clicker"),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: !_isAutoClickerRunning ? null : _stopAutoClicker,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Text("Stop Auto Clicker"),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _isAutoClickerRunning
                                ? "Auto Clicker is Running"
                                : "Auto Clicker is Stopped",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _isAutoClickerRunning ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Overlay for loading
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
