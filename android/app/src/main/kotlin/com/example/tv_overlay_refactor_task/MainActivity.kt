package com.example.tv_overlay_refactor_task

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tv_overlay_refactor_task/device",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getDeviceInfo") {
                val manager =
                    getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                val isEmulator =
                    Build.FINGERPRINT.startsWith("generic") ||
                        Build.FINGERPRINT.contains("emulator") ||
                        Build.MODEL.contains("Emulator") ||
                        Build.MODEL.contains("Android SDK built for") ||
                        Build.HARDWARE.contains("goldfish") ||
                        Build.HARDWARE.contains("ranchu")

                result.success(
                    mapOf(
                        "isTv" to (
                            manager.currentModeType ==
                                Configuration.UI_MODE_TYPE_TELEVISION
                        ),
                        "isEmulator" to isEmulator,
                    ),
                )
            } else {
                result.notImplemented()
            }
        }
    }
}
