import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/foundation.dart';
void initializeBackgroundService() {
  final service = FlutterBackgroundService();
 if (kIsWeb) {
    // Если это веб, не запускаем фоновый сервис
    print("Фоновый сервис не поддерживается на Web.");
    return;
  }
  service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundTask,
      autoStart: true,  // Сервис будет запускаться автоматически
      isForegroundMode: true, // Работает в фоновом режиме
      // notificationTitle: "Автокликер",
      // notificationContent: "Автокликер работает в фоновом режиме...",
      // notificationIcon: 'resource_icon', // Убедитесь, что иконка добавлена в res/drawable
      foregroundServiceNotificationId: 888, // ID уведомления для фона
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true, // Автозапуск на iOS
    ),
  );

  // Если у вас есть необходимость проверять статус работы сервиса:
  service.isRunning().then((isRunning) {
    if (!isRunning) {
      // Сервис будет автоматически работать в фоне
      print("Сервис будет работать в фоне.");
    }
  });

  // Нет необходимости вызывать service.start() при autoStart: true
  // service.start(); // Удалите или прокомментируйте этот вызов.
}

void backgroundTask(ServiceInstance service) async {
  // Этот код будет выполняться в фоновом режиме
  print("Фоновая задача выполняется...");

  // Пример: отправка данных в службу через invoke
  service.invoke('setData', {
    "message": "Фоновая задача в процессе."
  });

  // Для демонстрации отправляем сообщение каждые 10 секунд
  while (true) {
    await Future.delayed(Duration(seconds: 10));
    service.invoke('setData', {
      "message": "Фоновая задача работает ${DateTime.now()}."
    });
  }
}

void main() {
  // Инициализация перед запуском приложения
  WidgetsFlutterBinding.ensureInitialized();
  initializeBackgroundService();  // Стартуем фоновый сервис

  // Запуск приложения без UI (пустой контейнер, так как UI не нужен)
  runApp(MaterialApp(
    home: Container(),
  ));
}
