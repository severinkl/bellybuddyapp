package com.bellybuddy.belly_buddy

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // NotificationRepository.openNotificationSettings: where the user
        // allows the app's notifications once the OS won't ask any more.
        // openAppSettings (url_utils): the app's details page, e.g. for the
        // camera permission.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "belly_buddy/app_settings")
            .setMethodCallHandler { call, result ->
                val detailsIntent =
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null),
                    )
                val intent =
                    when (call.method) {
                        "openAppSettings" -> detailsIntent
                        "openNotificationSettings" ->
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                detailsIntent
                            }
                        else -> {
                            result.notImplemented()
                            return@setMethodCallHandler
                        }
                    }
                try {
                    startActivity(intent)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.success(false)
                }
            }
    }
}
