package com.example.indriveauto

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.graphics.Path
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.view.accessibility.AccessibilityNodeInfoCompat
import kotlin.collections.ArrayDeque
import android.content.SharedPreferences
import android.accessibilityservice.GestureDescription


class AutoClickService : AccessibilityService() {

    private lateinit var handler: Handler
    private lateinit var prefs: SharedPreferences
    private var targetPrice: String? = null
    private var clickInterval: Long = 1000
    private var swipeInterval: Long = 2000
    private var isSwiping = false

    companion object {
        var isAutoClickerRunning = false
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        handler = Handler(Looper.getMainLooper())
        prefs = getSharedPreferences("settings", Context.MODE_PRIVATE)
        Log.d("AutoClickService", "Service connected")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")
        Log.d("AutoClickService", "Received action: $action")

        when (action) {
            "_startAutoClicker" -> {
                val price = intent.getStringExtra("price") ?: return START_NOT_STICKY
                val clickMs = intent.getLongExtra("clickInterval", 1000)
                val swipeMs = intent.getLongExtra("swipeInterval", 2000)
                startAutoClicking(price, clickMs, swipeMs)
            }

            "_stopAutoClicker" -> {
                stopAutoClicking()
            }
        }

        return START_STICKY
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Не используется
    }

    override fun onInterrupt() {
        stopClicking()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopClicking()
    }

    fun startAutoClicking(price: String, clickMs: Long, swipeMs: Long) {
        Log.d("AutoClickService", "Starting auto clicker: price=$price")
        targetPrice = price
        clickInterval = clickMs
        swipeInterval = swipeMs

        prefs.edit()
            .putString("target_price", price)
            .putLong("click_interval", clickMs)
            .putLong("swipe_interval", swipeMs)
            .apply()

        startClicking()
    }

    fun stopAutoClicking() {
        Log.d("AutoClickService", "Stopping auto clicker")
        stopClicking()
    }

    private fun startClicking() {
        isAutoClickerRunning = true
        handler.post(object : Runnable {
            override fun run() {
                // Сначала обновляем экран, затем ищем и кликаем
                if (!isSwiping) {
                    performUpdateAndClick()
                }
                handler.postDelayed(this, swipeInterval)  // Регулярное обновление через указанный интервал
            }
        })

        // Добавляем регулярное обновление экрана каждую секунду
        handler.post(object : Runnable {
            override fun run() {
                swipeUp()  // Свайп вверх для обновления экрана
                handler.postDelayed(this, 1000)  // Регулярное обновление каждую секунду
            }
        })
    }

    private fun stopClicking() {
        isAutoClickerRunning = false
        handler.removeCallbacksAndMessages(null)
    }

    private fun performUpdateAndClick() {
        val rootNode = rootInActiveWindow ?: return
        val targetPriceText = targetPrice?.replace(" ", "") ?: return  // Убираем пробелы в целевой цене

        // Ищем все элементы с текстом, содержащим целевую цену
        val targetNodes = findNodesByText(rootNode, targetPriceText)

        if (targetNodes.isNotEmpty()) {
            // Если цена найдена, кликаем по карточке
            for (node in targetNodes) {
                clickOnCard(node)  // Кликаем по всей карточке
            }
        } else {
            // Если элементы с нужной ценой не найдены, выполняем свайп для обновления
            isSwiping = true
            handler.postDelayed({
                swipeUp()  // Свайп вверх
                isSwiping = false
            }, swipeInterval)
        }
    }

    private fun clickOnCard(node: AccessibilityNodeInfo) {
        // Пройдем по всем дочерним элементам карточки и кликаем по каждому
        val children = getAllChildren(node)
        for (child in children) {
            child.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            Log.d("AutoClickService", "Clicked on a part of the card.")
        }
    }

    private fun getAllChildren(node: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val children = mutableListOf<AccessibilityNodeInfo>()
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(node)

        while (queue.isNotEmpty()) {
            val currentNode = queue.removeFirst()
            for (i in 0 until currentNode.childCount) {
                val child = currentNode.getChild(i)
                child?.let { 
                    children.add(it)
                    queue.add(it)
                }
            }
        }
        return children
    }

    private fun swipeUp() {
        // Получаем размеры экрана для адаптивных свайпов
        val screenHeight = getScreenHeight()
        val screenWidth = getScreenWidth()
        val startX = screenWidth / 2
        val startY = screenHeight * 0.8f  // Начальная позиция на экране (80% высоты экрана)
        val endY = screenHeight * 0.2f    // Конечная позиция (20% высоты экрана)

        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(startX, endY)
        }

        val gestureBuilder = GestureDescription.Builder()
        gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 0, 500))
        
        // Отправляем жест на экран
        dispatchGesture(gestureBuilder.build(), object : AccessibilityService.GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                super.onCompleted(gestureDescription)
                Log.d("AutoClickService", "Swipe completed")
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                super.onCancelled(gestureDescription)
                Log.d("AutoClickService", "Swipe cancelled")
            }
        }, null)
    }

    private fun findNodesByText(root: AccessibilityNodeInfo, text: String): List<AccessibilityNodeInfo> {
        val nodes = mutableListOf<AccessibilityNodeInfo>()
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)

        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()
            val nodeText = node.text?.toString()?.replace(" ", "") ?: ""  // Убираем пробелы в тексте элемента

            // Сравниваем текст элемента с целевой ценой
            if (nodeText.contains(text, ignoreCase = true)) {
                nodes.add(node)
            }
            // Добавляем детей в очередь для дальнейшего поиска
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { queue.add(it) }
            }
        }
        return nodes
    }

    // Получение ширины экрана
    private fun getScreenWidth(): Float {
        val displayMetrics = DisplayMetrics()
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager.defaultDisplay.getMetrics(displayMetrics)
        return displayMetrics.widthPixels.toFloat()
    }

    // Получение высоты экрана
    private fun getScreenHeight(): Float {
        val displayMetrics = DisplayMetrics()
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager.defaultDisplay.getMetrics(displayMetrics)
        return displayMetrics.heightPixels.toFloat()
    }

    // Для отладки
    private fun logNodeTree(node: AccessibilityNodeInfo?, indent: String = "") {
        if (node == null) return

        Log.d("NodeTree", "$indent- ${node.className} | text=${node.text} | desc=${node.contentDescription}")

        for (i in 0 until node.childCount) {
            logNodeTree(node.getChild(i), "$indent  ")
        }
    }

    // Для отладки, чтобы увидеть все элементы
    private fun logNodeTreeForDebugging() {
        val rootNode = rootInActiveWindow
        if (rootNode != null) {
            logNodeTree(rootNode)
        } else {
            Log.d("AutoClickService", "rootInActiveWindow пустой.")
        }
    }
}
