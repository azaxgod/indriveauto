package com.example.indriveauto

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class MainActivity : FlutterActivity() {
    private val CHANNEL = "autoclick_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAutoClicker" -> {
                    val price: String? = call.argument("price")
                    val clickInterval: Long? = call.argument("clickInterval")
                    val swipeInterval: Long? = call.argument("swipeInterval")

                    if (price.isNullOrEmpty()) {
                        result.error("PRICE_ERROR", "Цена не передана", null)
                    } else {
                        saveTargetPrice(price, clickInterval, swipeInterval)
                        startAutoClickService(result)
                    }
                }
                "stopAutoClicker" -> stopAutoClickService(result)
                "updateSettings" -> {
                    val clickInterval: Long? = call.argument("clickInterval")
                    val swipeInterval: Long? = call.argument("swipeInterval")
                    updateSettings(clickInterval, swipeInterval)
                    result.success("Settings updated")
                }
                "isServiceEnabled" -> result.success(isAccessibilityServiceEnabled())
                "openAccessibilitySettings" -> openAccessibilitySettings(result)
                "isAutoClickerRunning" -> result.success(AutoClickService.isAutoClickerRunning)
                else -> result.notImplemented()
            }
        }
    }

    private fun updateSettings(clickInterval: Long?, swipeInterval: Long?) {
        val prefs = getSharedPreferences("settings", Context.MODE_PRIVATE)
        prefs.edit().apply {
            if (clickInterval != null) putLong("click_interval", clickInterval)
            if (swipeInterval != null) putLong("swipe_interval", swipeInterval)
        }.apply()

        // Перезапускаем сервис, чтобы применить новые настройки
        stopAutoClickServiceWithoutResult()
        startAutoClickServiceWithoutResult()
    }

    private fun saveTargetPrice(price: String, clickInterval: Long?, swipeInterval: Long?) {
        val prefs = getSharedPreferences("settings", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("target_price", price)
            putLong("click_interval", clickInterval ?: 1000)
            putLong("swipe_interval", swipeInterval ?: 2000)
        }.apply()
    }

    private fun startAutoClickService(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, AutoClickService::class.java)
            startService(intent)
            AutoClickService.isAutoClickerRunning = true
            result.success("Started auto-clicker")
        } catch (e: Exception) {
            result.error("SERVICE_ERROR", "Не удалось запустить сервис: ${e.message}", null)
        }
    }

    private fun startAutoClickServiceWithoutResult() {
        try {
            val intent = Intent(this, AutoClickService::class.java)
            startService(intent)
            AutoClickService.isAutoClickerRunning = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopAutoClickService(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, AutoClickService::class.java)
            stopService(intent)
            AutoClickService.isAutoClickerRunning = false
            result.success("Stopped auto-clicker")
        } catch (e: Exception) {
            result.error("SERVICE_ERROR", "Не удалось остановить сервис: ${e.message}", null)
        }
    }

    private fun stopAutoClickServiceWithoutResult() {
        try {
            val intent = Intent(this, AutoClickService::class.java)
            stopService(intent)
            AutoClickService.isAutoClickerRunning = false
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        return !TextUtils.isEmpty(enabledServices) && enabledServices.contains(AutoClickService::class.java.name)
    }

    private fun openAccessibilitySettings(result: MethodChannel.Result) {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivity(intent)
        result.success("Opened accessibility settings")
    }
}
