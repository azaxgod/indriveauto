package com.example.indriveauto

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.graphics.Path
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class AutoClickService : AccessibilityService() {

    companion object {
        var isAutoClickerRunning = false
    }

    private var targetPrice: String? = null
    private var clickInterval: Long = 1000L
    private var swipeInterval: Long = 2000L
    private var isRunning = false
    private lateinit var handler: Handler

    override fun onServiceConnected() {
        super.onServiceConnected()
        val prefs = applicationContext.getSharedPreferences("settings", Context.MODE_PRIVATE)
        targetPrice = prefs.getString("target_price", "2000")
        clickInterval = prefs.getLong("click_interval", 1000L)
        swipeInterval = prefs.getLong("swipe_interval", 2000L)
        handler = Handler(Looper.getMainLooper())

        Log.d("AutoClicker", "Service connected. Target price: $targetPrice, clickInterval: $clickInterval, swipeInterval: $swipeInterval")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Пусто: всё теперь обрабатываем через авто-рутину
    }

    override fun onInterrupt() {
        stopAutoClicking()
    }

    private val autoClickRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return

            val rootNode = rootInActiveWindow
            if (rootNode == null) {
                Log.w("AutoClicker", "Root node is null, stopping the service.")
                stopAutoClicking()
                return
            }

            if (!searchAndClickTarget(rootNode)) {
                performSwipeDown()
                handler.postDelayed({ performSwipeUp() }, swipeInterval)
            }

            handler.postDelayed(this, clickInterval)
        }
    }

    private fun searchAndClickTarget(rootNode: AccessibilityNodeInfo): Boolean {
        val formattedPrice = formatPriceWithSpaces(targetPrice ?: return false)

        Log.d("AutoClicker", "Searching for: $formattedPrice or 'С попутчиками'")

        val nodesToClick = findNodesByText(rootNode, formattedPrice) + findNodesByText(rootNode, "С попутчиками")
        
        for (node in nodesToClick) {
            if (clickOnNode(node)) {
                Log.d("AutoClicker", "Clicked on node: ${node.text}")
                return true
            }
        }
        
        Log.d("AutoClicker", "No matching nodes found.")
        return false
    }

    private fun findNodesByText(root: AccessibilityNodeInfo?, text: String): List<AccessibilityNodeInfo> {
        if (root == null) return emptyList()

        val result = mutableListOf<AccessibilityNodeInfo>()
        val cleanedTarget = cleanText(text)

        fun recursiveSearch(node: AccessibilityNodeInfo?) {
            if (node == null) return

            val nodeText = node.text?.toString() ?: ""
            if (cleanText(nodeText).contains(cleanedTarget)) {
                result.add(node)
            }

            for (i in 0 until node.childCount) {
                recursiveSearch(node.getChild(i))
            }
        }

        recursiveSearch(root)
        return result
    }

    private fun clickOnNode(node: AccessibilityNodeInfo): Boolean {
        var clickableNode: AccessibilityNodeInfo? = node
        while (clickableNode != null) {
            if (clickableNode.isClickable) {
                clickableNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                return true
            }
            clickableNode = clickableNode.parent
        }
        return false
    }

    private fun performSwipeDown() {
        val path = Path()
        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels

        val startX = screenWidth / 2f
        val startY = screenHeight / 3f
        val endX = startX
        val endY = startY + screenHeight / 2f

        path.moveTo(startX, startY)
        path.lineTo(endX, endY)

        val swipe = GestureDescription.StrokeDescription(path, 0, 500)
        val gesture = GestureDescription.Builder().addStroke(swipe).build()

        dispatchGesture(gesture, null, null)
        Log.d("AutoClicker", "Swipe Down performed.")
    }

    private fun performSwipeUp() {
        val path = Path()
        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels

        val startX = screenWidth / 2f
        val startY = screenHeight * 2f / 3f
        val endX = startX
        val endY = startY - screenHeight / 3f

        path.moveTo(startX, startY)
        path.lineTo(endX, endY)

        val swipe = GestureDescription.StrokeDescription(path, 0, 500)
        val gesture = GestureDescription.Builder().addStroke(swipe).build()

        dispatchGesture(gesture, null, null)
        Log.d("AutoClicker", "Swipe Up performed.")
    }

    private fun formatPriceWithSpaces(price: String): String {
        return price.replace(Regex("(\\d)(?=(\\d{3})+\$)"), "$1 ")
    }

    private fun cleanText(text: String): String {
        return text.replace("\\s+".toRegex(), "")
    }

    fun startAutoClicking() {
        if (isRunning) return
        isRunning = true
        isAutoClickerRunning = true
        handler.post(autoClickRunnable)
        Log.d("AutoClicker", "AutoClicker started.")
    }

    fun stopAutoClicking() {
        if (!isRunning) return
        isRunning = false
        isAutoClickerRunning = false
        handler.removeCallbacks(autoClickRunnable)
        Log.d("AutoClicker", "AutoClicker stopped.")
    }
}
