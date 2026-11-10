package com.studylock.studylock

import android.app.Activity
import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Process
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import org.json.JSONObject

class MonitorHost(private val activity: Activity) : NativeMonitorHostApi {
    companion object {
        fun install(activity: Activity, engine: FlutterEngine) {
            NativeMonitorHostApi.setUp(engine.dartExecutor.binaryMessenger, MonitorHost(activity))
        }
    }
    override fun getInstalledApps(): List<InstalledAppInfo> {
        val pm = activity.packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(launcher, 0).distinctBy { it.activityInfo.packageName }
            .filter { it.activityInfo.packageName != activity.packageName &&
                (it.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0 }
            .map {
                val category = if (Build.VERSION.SDK_INT >= 26) when (it.activityInfo.applicationInfo.category) {
                    ApplicationInfo.CATEGORY_GAME -> "游戏娱乐"
                    ApplicationInfo.CATEGORY_VIDEO -> "短视频"
                    ApplicationInfo.CATEGORY_SOCIAL -> "社交社区"
                    else -> "其他"
                } else "其他"
                InstalledAppInfo(it.activityInfo.packageName, it.loadLabel(pm).toString(), null, category)
            }
            .sortedBy { it.name }
    }
    override fun getPermissionStatus(): Map<String, Boolean> {
        val ops = activity.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val admin = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val enabled = Settings.Secure.getString(activity.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
        return mapOf(
            "usage" to (ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), activity.packageName) == AppOpsManager.MODE_ALLOWED),
            "accessibility" to enabled.split(':').any { ComponentName.unflattenFromString(it) == ComponentName(activity, StudyAccessibilityService::class.java) },
            "overlay" to Settings.canDrawOverlays(activity),
            "admin" to admin.isAdminActive(ComponentName(activity, StudyAdminReceiver::class.java))
        )
    }
    override fun requestPermission(permission: String) {
        val intent = when (permission) {
            "usage" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            "overlay" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${activity.packageName}"))
            "admin" -> Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, ComponentName(activity, StudyAdminReceiver::class.java))
                putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "由监督者主动开启，帮助保护已经约定的学习节奏。")
            }
            "disableAdmin" -> {
                val admin = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                admin.removeActiveAdmin(ComponentName(activity, StudyAdminReceiver::class.java))
                return
            }
            else -> throw IllegalArgumentException("Unknown permission")
        }
        // A short, bounded exemption lets the owner grant the permissions they requested.
        GuardEngine.allowSystemSettingsFor(120_000)
        activity.startActivity(intent)
    }
    override fun syncMonitorPolicy(policyJson: String) { GuardEngine.init(activity); GuardEngine.setPolicy(JSONObject(policyJson)) }
    override fun setGuardEnabled(enabled: Boolean) {
        GuardEngine.init(activity)
        if (enabled && !getPermissionStatus().filterKeys { it != "admin" }.values.all { it }) {
            throw IllegalStateException("Required permissions are missing")
        }
        GuardEngine.setEnabled(enabled)
    }
    override fun notifyQuizPassed() {
        GuardEngine.init(activity); GuardEngine.unlock()
        if (activity is LockActivity) activity.finish()
    }
    override fun getMonitorState(): String {
        GuardEngine.init(activity)
        // Revoked permissions must never leave the console claiming active protection.
        if (GuardEngine.enabled && !getPermissionStatus().filterKeys { it != "admin" }.values.all { it }) {
            GuardEngine.setEnabled(false)
        }
        return GuardEngine.snapshot().toString()
    }
    override fun openEmergencyDialer() {
        // ACTION_DIAL keeps phone numbers and the final call under the user's control.
        activity.startActivity(Intent(Intent.ACTION_DIAL).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) })
    }
}
