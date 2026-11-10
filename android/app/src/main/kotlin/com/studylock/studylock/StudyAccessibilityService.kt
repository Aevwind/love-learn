package com.studylock.studylock

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.roundToInt

class StudyAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var banner: LinearLayout? = null
    private val tick = object : Runnable {
        override fun run() {
            GuardEngine.tick()
            val remaining = GuardEngine.remainingSeconds()
            if (GuardEngine.shouldWarn()) showWarning(remaining) else hideWarning()
            if (GuardEngine.locked && !GuardEngine.isEmergencyForeground()) {
                hideWarning()
                if (!LockActivity.visible) {
                    try { startActivity(Intent(this@StudyAccessibilityService, LockActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)) } catch (_: Exception) { }
                }
            }
            handler.postDelayed(this, 1000)
        }
    }
    override fun onServiceConnected() {
        GuardEngine.init(this); handler.removeCallbacks(tick); handler.post(tick)
    }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val sourcePackage = event.packageName?.toString() ?: return
        // Our non-focusable warning overlay emits window events too. It must not
        // replace the app underneath it and pause its usage timer. Real host
        // activities report their foreground state through their lifecycle.
        if (sourcePackage == packageName) return
        GuardEngine.foreground(sourcePackage)
    }
    override fun onInterrupt() { hideWarning() }
    override fun onDestroy() { handler.removeCallbacks(tick); hideWarning(); super.onDestroy() }
    private fun showWarning(seconds: Long) {
        val width = (resources.displayMetrics.widthPixels * .95f).roundToInt()
        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        if (banner == null) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL; setPadding(40, 30, 40, 30)
                background = android.graphics.drawable.GradientDrawable().apply {
                    setColor(Color.rgb(237, 246, 232)); cornerRadius = 40f; setStroke(2, Color.WHITE)
                }
                elevation = 16f
            }
            val title = TextView(this).apply { setTextColor(Color.rgb(62, 102, 83)); textSize = 14f }
            val detail = TextView(this).apply { text = "收好手边的事，准备给大脑充点电。"; setTextColor(Color.rgb(110, 133, 116)); textSize = 11f }
            row.addView(title); row.addView(detail)
            row.setOnClickListener { GuardEngine.trigger(); hideWarning() }
            val params = WindowManager.LayoutParams(width, WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                android.graphics.PixelFormat.TRANSLUCENT).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL; y = 70
            }
            try { windowManager.addView(row, params); banner = row } catch (_: Exception) { }
        } else {
            val params = banner!!.layoutParams as WindowManager.LayoutParams
            if (params.width != width) {
                params.width = width
                try { windowManager.updateViewLayout(banner, params) } catch (_: Exception) { }
            }
        }
        (banner?.getChildAt(0) as? TextView)?.text = "还有 ${seconds} 秒 · 到学习充电的时间啦"
    }
    private fun hideWarning() {
        banner?.let { try { (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(it) } catch (_: Exception) { } }
        banner = null
    }
}
