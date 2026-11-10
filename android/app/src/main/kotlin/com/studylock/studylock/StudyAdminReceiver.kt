package com.studylock.studylock

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class StudyAdminReceiver : DeviceAdminReceiver() {
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence =
        "停用设备管理保护会降低守护强度。建议先在爱学习安全中心解除保护。"
}
