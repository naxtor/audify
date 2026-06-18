package id.nabilfaris.audify_example

import android.media.MediaPlayer
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var mediaPlayer: MediaPlayer? = null
    private var isPrepared = false
    private var isCompleted = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "audify_example/audio_player"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "load" -> {
                    val asset = call.argument<String>("asset")
                    if (asset == null) {
                        result.error("invalid_argument", "Missing asset path", null)
                    } else {
                        loadAsset(asset)
                        result.success(null)
                    }
                }
                "play" -> {
                    mediaPlayer?.start()
                    isCompleted = false
                    result.success(null)
                }
                "pause" -> {
                    mediaPlayer?.pause()
                    result.success(null)
                }
                "stop" -> {
                    mediaPlayer?.pause()
                    mediaPlayer?.seekTo(0)
                    isCompleted = false
                    result.success(null)
                }
                "seek" -> {
                    val positionMs = call.argument<Int>("positionMs") ?: 0
                    mediaPlayer?.seekTo(positionMs.coerceAtLeast(0))
                    isCompleted = false
                    result.success(null)
                }
                "getState" -> result.success(currentState())
                "release" -> {
                    releasePlayer()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun loadAsset(asset: String) {
        releasePlayer()

        val assetKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        val audioFile = File(cacheDir, "audify_example_music.mp3")
        assets.open(assetKey).use { input ->
            audioFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        mediaPlayer = MediaPlayer().apply {
            setDataSource(audioFile.absolutePath)
            setOnCompletionListener {
                isCompleted = true
                seekTo(0)
            }
            prepare()
        }
        isPrepared = true
        isCompleted = false
    }

    private fun currentState(): Map<String, Any> {
        val player = mediaPlayer
        return mapOf(
            "isPlaying" to (player?.isPlaying == true),
            "isCompleted" to isCompleted,
            "durationMs" to if (isPrepared && player != null) player.duration else 0,
            "positionMs" to if (isPrepared && player != null && !isCompleted) {
                player.currentPosition
            } else {
                0
            }
        )
    }

    private fun releasePlayer() {
        mediaPlayer?.release()
        mediaPlayer = null
        isPrepared = false
        isCompleted = false
    }
}
