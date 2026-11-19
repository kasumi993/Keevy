package app.keevy.keevy

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Receives "Share to Keevy" intents (text, links, images) from other apps and
 * hands them to Flutter through the `app.keevy/share` channel.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val pending = mutableListOf<Map<String, String>>()

    /** True when this activity was started by a share intent: after saving we go back to the source app. */
    private var launchedFromShare = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null && isShareIntent(intent)) {
            launchedFromShare = true
            collect(intent)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePending" -> {
                        val items = ArrayList(pending)
                        pending.clear()
                        result.success(items)
                    }
                    "finishShare" -> {
                        if (launchedFromShare) {
                            launchedFromShare = false
                            finish()
                        }
                        result.success(null)
                    }
                    "syncBoards" -> result.success(null) // iOS only (share extension board list)
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (isShareIntent(intent)) {
            setIntent(intent)
            collect(intent)
            channel?.invokeMethod("onShare", null)
        }
    }

    private fun isShareIntent(intent: Intent?): Boolean =
        intent != null && (intent.action == Intent.ACTION_SEND || intent.action == Intent.ACTION_SEND_MULTIPLE)

    private fun collect(intent: Intent) {
        val type = intent.type ?: return
        when {
            intent.action == Intent.ACTION_SEND && type.startsWith("text/") -> {
                val text = listOfNotNull(
                    intent.getStringExtra(Intent.EXTRA_SUBJECT)?.takeIf { s ->
                        // Some apps put the title in SUBJECT and the URL in TEXT: keep both.
                        val body = intent.getStringExtra(Intent.EXTRA_TEXT)
                        body == null || !body.contains(s)
                    },
                    intent.getStringExtra(Intent.EXTRA_TEXT),
                ).joinToString("\n").trim()
                if (text.isNotEmpty()) pending.add(mapOf("type" to "text", "value" to text))
            }
            intent.action == Intent.ACTION_SEND && type.startsWith("image/") -> {
                streamUri(intent)?.let { copyToCache(it, type) }?.let {
                    pending.add(mapOf("type" to "image", "value" to it.absolutePath, "mimeType" to type))
                }
            }
            intent.action == Intent.ACTION_SEND_MULTIPLE && type.startsWith("image/") -> {
                streamUris(intent).take(10).forEach { uri ->
                    copyToCache(uri, type)?.let {
                        pending.add(mapOf("type" to "image", "value" to it.absolutePath, "mimeType" to type))
                    }
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun streamUri(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun streamUris(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)) ?: emptyList()

    /** Content URIs are only readable while the intent lives: copy the file into the app cache. */
    private fun copyToCache(uri: Uri, fallbackMime: String): File? = try {
        val mime = contentResolver.getType(uri) ?: fallbackMime
        val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "jpg"
        val dir = File(cacheDir, "shared").apply { mkdirs() }
        val file = File(dir, "share_${System.currentTimeMillis()}_${(0..9999).random()}.$ext")
        contentResolver.openInputStream(uri)?.use { input -> file.outputStream().use { input.copyTo(it) } }
        if (file.exists() && file.length() > 0) file else null
    } catch (e: Exception) {
        null
    }

    companion object {
        private const val CHANNEL = "app.keevy/share"
    }
}
