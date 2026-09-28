package de.blaupeil.blaupeil

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelUuid

/**
 * Sendermodus auf Android.
 *
 * Warum eigener Code statt flutter_ble_peripheral: Android kann keinen frei
 * wählbaren Local Name funken, nur „Gerätename mitsenden“. Damit das Format
 * zu iOS passt (Name „BP-XXXXX“), setzt der Service den Bluetooth-Namen des
 * Geräts für die Dauer des Sendens auf „BP-…“ und stellt ihn danach wieder
 * her. Außerdem läuft er als Foreground Service, sonst legt Android das
 * Advertising im Standby schlafen.
 *
 * Paketaufteilung: Service-UUID im Advertising-Paket, Name in der Scan
 * Response. Zusammen wären es genau 31 Byte; getrennt bleibt Luft, falls ein
 * Hersteller noch Felder ergänzt.
 */
@SuppressLint("MissingPermission") // Berechtigungen prüft hasBtPermissions()
class BeaconAdvertiserService : Service() {

    companion object {
        const val EXTRA_NAME = "localName"
        const val EXTRA_UUID = "serviceUuid"
        private const val ACTION_STOP = "de.blaupeil.blaupeil.STOP"
        private const val CHANNEL_ID = "sender"
        private const val NOTIFICATION_ID = 1
        private const val PREFS = "blaupeil_native"
        private const val KEY_ORIGINAL_NAME = "originalAdapterName"
        private const val NAME_POLL_MS = 100L
        private const val NAME_POLL_MAX = 30

        /** Service lebt und sendet (oder bereitet das Senden gerade vor). */
        @Volatile
        var running = false
            private set

        /** Letzter Fehler, damit Flutter ihn anzeigen kann. */
        @Volatile
        var lastError: String? = null
            private set

        private fun adapter(ctx: Context): BluetoothAdapter? =
            (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?)?.adapter

        private fun hasBtPermissions(ctx: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
            return listOf(
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.BLUETOOTH_CONNECT,
            ).all { ctx.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
        }

        /** Ursprünglichen Namen zurückholen, falls ein Sendevorgang abgebrochen wurde. */
        fun restoreNameIfOrphaned(ctx: Context) {
            if (running) return
            restoreName(ctx)
        }

        private fun restoreName(ctx: Context) {
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val original = prefs.getString(KEY_ORIGINAL_NAME, null) ?: return
            val adapter = adapter(ctx) ?: return
            if (!hasBtPermissions(ctx) || !adapter.isEnabled) return
            try {
                if (original.isNotEmpty()) adapter.setName(original)
                prefs.edit().remove(KEY_ORIGINAL_NAME).apply()
            } catch (e: SecurityException) {
                // Beim nächsten App-Start erneut versuchen.
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var advertiser: BluetoothLeAdvertiser? = null

    private val callback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            lastError = null
        }

        override fun onStartFailure(errorCode: Int) {
            fail(
                when (errorCode) {
                    ADVERTISE_FAILED_DATA_TOO_LARGE -> "Werbepaket zu groß."
                    ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Zu viele Apps senden gerade per Bluetooth."
                    ADVERTISE_FAILED_ALREADY_STARTED -> "Senden läuft bereits."
                    ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "Dieses Gerät unterstützt das Senden nicht."
                    else -> "Interner Bluetooth-Fehler ($errorCode)."
                }
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        val name = intent?.getStringExtra(EXTRA_NAME)
        val uuid = intent?.getStringExtra(EXTRA_UUID)

        // startForeground muss binnen weniger Sekunden nach dem Start kommen,
        // auch wenn danach etwas schiefgeht.
        try {
            enterForeground(name ?: "")
        } catch (e: Exception) {
            fail("Foreground Service nicht erlaubt: ${e.message}")
            return START_NOT_STICKY
        }
        if (name == null || uuid == null) {
            fail("Interner Fehler: Name oder UUID fehlt.")
            return START_NOT_STICKY
        }

        running = true
        lastError = null
        stopAdvertising()
        handler.removeCallbacksAndMessages(null)
        prepareAndAdvertise(name, uuid)
        // Nicht automatisch neu starten: ohne sichtbare App soll niemand
        // unbemerkt weiter senden.
        return START_NOT_STICKY
    }

    private fun prepareAndAdvertise(name: String, uuid: String) {
        val adapter = adapter(this)
        if (adapter == null) return fail("Kein Bluetooth vorhanden.")
        if (!hasBtPermissions(this)) return fail("Bluetooth-Berechtigung fehlt.")
        if (!adapter.isEnabled) return fail("Bluetooth ist aus.")
        val adv = adapter.bluetoothLeAdvertiser
            ?: return fail("Dieses Gerät unterstützt das Senden nicht.")
        advertiser = adv

        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        // Nur beim ersten Mal merken, sonst würde nach einem Absturz „BP-…“
        // als „Originalname“ gespeichert.
        if (!prefs.contains(KEY_ORIGINAL_NAME)) {
            prefs.edit().putString(KEY_ORIGINAL_NAME, adapter.name ?: "").apply()
        }
        if (adapter.name != name) adapter.setName(name)

        // setName wirkt asynchron. Kurz warten, sonst funkt die Scan Response
        // noch den alten Namen.
        waitForName(adapter, name, uuid, 0)
    }

    private fun waitForName(adapter: BluetoothAdapter, name: String, uuid: String, attempt: Int) {
        if (!running) return
        val ready = try {
            adapter.name == name
        } catch (e: SecurityException) {
            false
        }
        if (ready || attempt >= NAME_POLL_MAX) {
            startAdvertising(uuid)
        } else {
            handler.postDelayed({ waitForName(adapter, name, uuid, attempt + 1) }, NAME_POLL_MS)
        }
    }

    private fun startAdvertising(uuid: String) {
        val adv = advertiser ?: return
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0)
            .build()
        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid.fromString(uuid))
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .build()
        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .setIncludeTxPowerLevel(false)
            .build()
        try {
            adv.startAdvertising(settings, data, scanResponse, callback)
        } catch (e: Exception) {
            fail("Senden fehlgeschlagen: ${e.message}")
        }
    }

    private fun stopAdvertising() {
        try {
            advertiser?.stopAdvertising(callback)
        } catch (e: Exception) {
            // Bluetooth schon aus oder Berechtigung entzogen: nichts zu stoppen.
        }
    }

    private fun fail(message: String) {
        lastError = message
        stopSelf()
    }

    private fun enterForeground(name: String) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Sendermodus", NotificationManager.IMPORTANCE_LOW)
                .apply { description = "Zeigt an, solange dein Gerät sichtbar ist." }
        )
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this, 1,
            Intent(this, BeaconAdvertiserService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle("Dein Gerät ist gerade sichtbar")
            .setContentText("BlauPeil sendet als $name")
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(this, android.R.drawable.ic_menu_close_clear_cancel),
                    "Beenden",
                    stop,
                ).build()
            )
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacksAndMessages(null)
        stopAdvertising()
        restoreName(this)
        super.onDestroy()
    }
}
