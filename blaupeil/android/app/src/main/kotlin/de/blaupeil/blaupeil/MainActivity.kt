package de.blaupeil.blaupeil

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Falls die App beim letzten Mal mitten im Senden beendet wurde, trägt
        // das Handy womöglich noch „BP-…“ als Bluetooth-Namen.
        BeaconAdvertiserService.restoreNameIfOrphaned(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "de.blaupeil/advertiser")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val name = call.argument<String>("localName")
                        val uuid = call.argument<String>("serviceUuid")
                        if (name == null || uuid == null) {
                            result.error("ARGS", "localName und serviceUuid fehlen", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(this, BeaconAdvertiserService::class.java)
                            .putExtra(BeaconAdvertiserService.EXTRA_NAME, name)
                            .putExtra(BeaconAdvertiserService.EXTRA_UUID, uuid)
                        try {
                            startForegroundService(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("START_FAILED", e.message, null)
                        }
                    }
                    "stop" -> {
                        stopService(Intent(this, BeaconAdvertiserService::class.java))
                        result.success(null)
                    }
                    "status" -> result.success(
                        mapOf(
                            "advertising" to BeaconAdvertiserService.running,
                            "error" to BeaconAdvertiserService.lastError,
                        )
                    )
                    else -> result.notImplemented()
                }
            }
    }
}
