package com.example.indriveauto

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "autoclick_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAutoClicker" -> {
                    try {
                        val price: String = call.argument("price") ?: ""
                        val clickInterval: Int = call.argument("clickInterval") ?: 1000
                        val swipeInterval: Int = call.argument("swipeInterval") ?: 2000

                        if (price.isEmpty()) {
                            result.error("PRICE_ERROR", "Цена не передана", null)
                            return@setMethodCallHandler
                        }

                        saveSettings(price, clickInterval.toLong(), swipeInterval.toLong())

                        val intent = Intent(this, AutoClickService::class.java).apply {
                            putExtra("action", "start")
                            putExtra("price", price)
                            putExtra("clickInterval", clickInterval.toLong())
                            putExtra("swipeInterval", swipeInterval.toLong())
                        }

                        startService(intent)
                        AutoClickService.isAutoClickerRunning = true
                        Log.d("MainActivity", "AutoClickService started")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error in startAutoClicker", e)
                        result.error("START_ERROR", "Ошибка при запуске автокликера: ${e.message}", null)
                    }
                }

                "stopAutoClicker" -> {
                    try {
                        val intent = Intent(this, AutoClickService::class.java).apply {
                            putExtra("action", "stop")
                        }

                        startService(intent)
                        AutoClickService.isAutoClickerRunning = false
                        Log.d("MainActivity", "AutoClickService stopped")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error stopping service", e)
                        result.error("STOP_ERROR", "Ошибка при остановке: ${e.message}", null)
                    }
                }

                "isAutoClickerRunning" -> {
                    result.success(AutoClickService.isAutoClickerRunning)
                }

                "isServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }

                "openAccessibilitySettings" -> {
                    openAccessibilitySettings(result)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun saveSettings(price: String, clickInterval: Long, swipeInterval: Long) {
        val prefs = getSharedPreferences("settings", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("target_price", price)
            putLong("click_interval", clickInterval)
            putLong("swipe_interval", swipeInterval)
        }.apply()
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        val expectedService = "$packageName/${AutoClickService::class.java.name}"
        return !TextUtils.isEmpty(enabledServices) && enabledServices!!.contains(expectedService)
    }

    private fun openAccessibilitySettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            result.success("Opened accessibility settings")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error opening accessibility settings", e)
            result.error("ACCESSIBILITY_SETTINGS_ERROR", "Ошибка при открытии настроек: ${e.message}", null)
        }
    }
}
