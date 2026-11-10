package com.studylock.studylock

import android.app.KeyguardManager
import android.content.Context
import android.content.SharedPreferences
import android.os.PowerManager
import android.os.SystemClock
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** All elapsed durations use elapsedRealtime; changing wall time never resets a cycle. */
object GuardEngine {
    private lateinit var context: Context
    private lateinit var prefs: SharedPreferences
    private var initialized = false
    private var policy = JSONObject()
    private var usage = JSONObject()
    private var cycles = JSONObject()
    private var sharedCycle = 0L
    private var guardMillis = 0L
    private var lastTick = 0L
    private var currentPackage = ""
    private var lockedPackage = ""
    private var unlockedSettingsUntil = 0L
    private var day = ""
    var enabled = false; private set
    var locked = false; private set
    @Synchronized fun init(c: Context) {
        if (initialized) return
        context = c.applicationContext
        prefs = context.getSharedPreferences("studylock_monitor", Context.MODE_PRIVATE)
        policy = JSONObject(prefs.getString("policy", "{}") ?: "{}")
        usage = JSONObject(prefs.getString("usage", "{}") ?: "{}")
        cycles = JSONObject(prefs.getString("cycles", "{}") ?: "{}")
        sharedCycle = prefs.getLong("sharedCycle", 0)
        guardMillis = prefs.getLong("guardMillis", 0)
        day = prefs.getString("day", today()) ?: today()
        enabled = prefs.getBoolean("enabled", false); locked = prefs.getBoolean("locked", false)
        lockedPackage = prefs.getString("lockedPackage", "") ?: ""
        lastTick = SystemClock.elapsedRealtime(); initialized = true
    }
    private fun today() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    @Synchronized fun setPolicy(value: JSONObject) { tick(); policy = value; persist() }
    @Synchronized fun setEnabled(value: Boolean) {
        tick(); enabled = value
        if (!value) locked = false
        lastTick = SystemClock.elapsedRealtime(); persist()
    }
    fun allowSystemSettingsFor(millis: Long) { unlockedSettingsUntil = SystemClock.elapsedRealtime() + millis }
    private fun packages() = policy.optJSONObject("packages") ?: JSONObject()
    private fun isProtectedSettings(): Boolean = policy.optBoolean("protectSettings", false) &&
        SystemClock.elapsedRealtime() >= unlockedSettingsUntil && (currentPackage == "com.android.settings" ||
        currentPackage.contains("packageinstaller") || currentPackage == "com.google.android.permissioncontroller")
    @Synchronized fun foreground(name: String) {
        if (!initialized) return
        tick()
        // Ignore transient system bars without collecting any accessibility text content.
        if (name == "com.android.systemui") return
        currentPackage = name
        if (enabled && isProtectedSettings()) trigger()
    }
    @Synchronized fun tick() {
        if (!initialized) return
        val now = SystemClock.elapsedRealtime()
        val delta = (now - lastTick).coerceIn(0, 5000)
        lastTick = now
        val date = today()
        if (date > day) { day = date; usage = JSONObject(); guardMillis = 0 }
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (enabled && power.isInteractive && !keyguard.isKeyguardLocked && !locked) {
            guardMillis += delta
            if (packages().has(currentPackage) && !isEmergencyForeground()) {
                usage.put(currentPackage, usage.optLong(currentPackage) + delta)
                cycles.put(currentPackage, cycles.optLong(currentPackage) + delta)
                sharedCycle += delta
                if (remainingSeconds() <= 0) trigger()
            }
        }
        persist()
    }
    fun remainingSeconds(): Long {
        if (!initialized) return 0
        val cumulative = policy.optBoolean("cumulative", true)
        val limit = if (cumulative) policy.optLong("limitMinutes", 30) * 60
            else packages().optJSONObject(currentPackage)?.optLong("limitSeconds", 1800) ?: 1800
        val elapsed = if (cumulative) sharedCycle else cycles.optLong(currentPackage)
        return ((limit * 1000 - elapsed + 999) / 1000).coerceAtLeast(0)
    }
    fun shouldWarn() = initialized && enabled && !locked && policy.optBoolean("warning", true) &&
        packages().has(currentPackage) && remainingSeconds() in 1..60
    fun isEmergencyForeground(): Boolean = currentPackage.contains("dialer") || currentPackage.contains("incallui") ||
        currentPackage == "com.android.phone" || currentPackage.contains("emergency") || currentPackage.contains("telecom")
    @Synchronized fun trigger() { if (!enabled) return; locked = true; lockedPackage = currentPackage; persist() }
    @Synchronized fun unlock() {
        locked = false
        if (policy.optBoolean("cumulative", true)) { sharedCycle = 0; cycles = JSONObject() }
        else { cycles.put(lockedPackage, 0) }
        // Keep the system permission screen reachable briefly after a successful quiz.
        if (lockedPackage.contains("settings") || lockedPackage.contains("installer")) allowSystemSettingsFor(60_000)
        lastTick = SystemClock.elapsedRealtime(); persist()
    }
    @Synchronized fun snapshot(): JSONObject {
        val seconds = JSONObject()
        usage.keys().forEach { seconds.put(it, usage.optLong(it) / 1000) }
        return JSONObject().put("enabled", enabled).put("locked", locked).put("date", day)
            .put("remainingSeconds", remainingSeconds()).put("usage", seconds)
            .put("guardSeconds", guardMillis / 1000).put("triggeredPackage", lockedPackage)
    }
    private fun persist() {
        if (!initialized) return
        prefs.edit().putString("policy", policy.toString()).putString("usage", usage.toString())
            .putString("cycles", cycles.toString()).putLong("sharedCycle", sharedCycle)
            .putLong("guardMillis", guardMillis).putString("day", day).putBoolean("enabled", enabled)
            .putBoolean("locked", locked).putString("lockedPackage", lockedPackage).apply()
    }
}
