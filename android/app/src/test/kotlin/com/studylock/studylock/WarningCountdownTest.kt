package com.studylock.studylock

import android.content.Context
import android.os.Looper
import android.os.PowerManager
import android.view.accessibility.AccessibilityEvent
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import org.robolectric.util.ReflectionHelpers
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
@LooperMode(LooperMode.Mode.PAUSED)
class WarningCountdownTest {
    private lateinit var service: StudyAccessibilityService
    private val game = "com.example.monitoredgame"

    @Before fun startGuard() {
        service = Robolectric.buildService(StudyAccessibilityService::class.java).create().get()
        val power = service.getSystemService(Context.POWER_SERVICE) as PowerManager
        shadowOf(power).setIsInteractive(true)
        GuardEngine.init(service)
        GuardEngine.setEnabled(false)
        GuardEngine.setPolicy(JSONObject().put("cumulative", true).put("limitMinutes", 1)
            .put("warning", true).put("packages", JSONObject().put(game,
                JSONObject().put("name", "Test game").put("limitSeconds", 60))))
        GuardEngine.unlock()
        GuardEngine.foreground(game)
        GuardEngine.setEnabled(true)
        ReflectionHelpers.callInstanceMethod<Void>(service, "onServiceConnected")
        shadowOf(Looper.getMainLooper()).idle()
    }

    @After fun stopGuard() {
        service.onDestroy()
        GuardEngine.setEnabled(false)
    }

    private fun windowChanged(packageName: String) {
        val event = AccessibilityEvent.obtain(AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED)
        event.packageName = packageName
        event.className = "android.widget.LinearLayout"
        service.onAccessibilityEvent(event)
    }

    private fun banner(): LinearLayout? = ReflectionHelpers.getField(service, "banner")

    @Test fun warningTicksWithoutTouchAfterItsOwnOverlayWindowEvent() {
        assertEquals(60L, GuardEngine.remainingSeconds())
        windowChanged(service.packageName)

        // Advance only the main looper: no clicks, gestures or further accessibility events.
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertEquals(59L, GuardEngine.remainingSeconds())
        assertTrue(GuardEngine.shouldWarn())
        assertNotNull(banner())
        assertEquals("还有 59 秒 · 到学习充电的时间啦", (banner()!!.getChildAt(0) as TextView).text.toString())

        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))
        assertEquals(57L, GuardEngine.remainingSeconds())
        assertEquals("还有 57 秒 · 到学习充电的时间啦", (banner()!!.getChildAt(0) as TextView).text.toString())
    }

    @Test fun switchingToAnotherApplicationPausesUsageAndHidesWarning() {
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))
        windowChanged("com.example.notes")
        val remaining = GuardEngine.remainingSeconds()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(3))
        assertEquals(remaining, GuardEngine.remainingSeconds())
        assertFalse(GuardEngine.shouldWarn())
        assertNull(banner())
    }

    @Test fun actualHostActivityForegroundStillPausesUsage() {
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))
        // The actual MainActivity / LockActivity lifecycle reports this directly.
        GuardEngine.foreground(service.packageName)
        windowChanged(service.packageName)
        val remaining = GuardEngine.remainingSeconds()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(3))
        assertEquals(58L, remaining)
        assertEquals(remaining, GuardEngine.remainingSeconds())
        assertNull(banner())
    }

    @Test fun independentAppCountdownAlsoContinuesAfterOverlayEvent() {
        GuardEngine.setPolicy(JSONObject().put("cumulative", false).put("warning", true)
            .put("packages", JSONObject().put(game, JSONObject().put("limitSeconds", 60))))
        windowChanged(service.packageName)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))
        assertEquals(58L, GuardEngine.remainingSeconds())
        assertTrue(GuardEngine.shouldWarn())
    }

    @Test fun countdownReachesZeroAndStartsInterceptionWithoutUserInput() {
        windowChanged(service.packageName)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(60))
        assertEquals(0L, GuardEngine.remainingSeconds())
        assertTrue(GuardEngine.locked)
        assertNull(banner())
        assertEquals(LockActivity::class.java.name,
            shadowOf(service.application).nextStartedActivity?.component?.className)
    }
}
