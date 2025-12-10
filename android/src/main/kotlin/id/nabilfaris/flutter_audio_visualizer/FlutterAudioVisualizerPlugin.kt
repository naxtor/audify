package id.nabilfaris.flutter_audio_visualizer

import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class FlutterAudioVisualizerPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var fftEventChannel: EventChannel
    private lateinit var waveformEventChannel: EventChannel
    
    private var visualizer: Visualizer? = null
    private var fftStreamHandler: AudioStreamHandler? = null
    private var waveformStreamHandler: AudioStreamHandler? = null
    
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_audio_visualizer")
        methodChannel.setMethodCallHandler(this)
        
        fftEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_audio_visualizer/fft")
        fftStreamHandler = AudioStreamHandler()
        fftEventChannel.setStreamHandler(fftStreamHandler)
        
        waveformEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_audio_visualizer/waveform")
        waveformStreamHandler = AudioStreamHandler()
        waveformEventChannel.setStreamHandler(waveformStreamHandler)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> {
                val audioSessionId = call.argument<Int>("audioSessionId") ?: 0
                initialize(audioSessionId, result)
            }
            "startCapture" -> {
                startCapture(result)
            }
            "stopCapture" -> {
                stopCapture(result)
            }
            "release" -> {
                release(result)
            }
            "setCaptureSize" -> {
                val size = call.argument<Int>("size") ?: 1024
                setCaptureSize(size, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initialize(audioSessionId: Int, result: Result) {
        try {
            visualizer?.release()
            visualizer = Visualizer(audioSessionId)
            
            visualizer?.apply {
                captureSize = Visualizer.getCaptureSizeRange()[1] // Max capture size
                enabled = false
                
                // Set up FFT data capture
                setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(
                        visualizer: Visualizer?,
                        waveform: ByteArray?,
                        samplingRate: Int
                    ) {
                        waveform?.let {
                            waveformStreamHandler?.sendData(it.toList())
                        }
                    }

                    override fun onFftDataCapture(
                        visualizer: Visualizer?,
                        fft: ByteArray?,
                        samplingRate: Int
                    ) {
                        fft?.let {
                            fftStreamHandler?.sendData(it.toList())
                        }
                    }
                }, Visualizer.getMaxCaptureRate() / 2, true, true)
            }
            
            result.success(true)
        } catch (e: Exception) {
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun startCapture(result: Result) {
        try {
            visualizer?.enabled = true
            result.success(true)
        } catch (e: Exception) {
            result.error("START_ERROR", e.message, null)
        }
    }

    private fun stopCapture(result: Result) {
        try {
            visualizer?.enabled = false
            result.success(true)
        } catch (e: Exception) {
            result.error("STOP_ERROR", e.message, null)
        }
    }

    private fun release(result: Result) {
        try {
            visualizer?.release()
            visualizer = null
            result.success(true)
        } catch (e: Exception) {
            result.error("RELEASE_ERROR", e.message, null)
        }
    }

    private fun setCaptureSize(size: Int, result: Result) {
        try {
            visualizer?.captureSize = size
            result.success(true)
        } catch (e: Exception) {
            result.error("SET_SIZE_ERROR", e.message, null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        fftEventChannel.setStreamHandler(null)
        waveformEventChannel.setStreamHandler(null)
        visualizer?.release()
        visualizer = null
    }

    private class AudioStreamHandler : EventChannel.StreamHandler {
        private var eventSink: EventChannel.EventSink? = null
        private val handler = Handler(Looper.getMainLooper())

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
        }

        fun sendData(data: List<Byte>) {
            handler.post {
                eventSink?.success(data)
            }
        }
    }
}