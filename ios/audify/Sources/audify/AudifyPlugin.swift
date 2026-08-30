import Flutter
import UIKit
import AVFoundation
import Accelerate

public class AudifyPlugin: NSObject, FlutterPlugin {
    private var audioEngine: AVAudioEngine?
    private var fftEventChannel: FlutterEventChannel?
    private var waveformEventChannel: FlutterEventChannel?
    private var fftStreamHandler: AudioStreamHandler?
    private var waveformStreamHandler: AudioStreamHandler?
    
    private var captureSize: Int = 2048
    private var isCapturing: Bool = false
    
    // FFT setup using Accelerate framework
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float] = []
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "audify",
            binaryMessenger: registrar.messenger()
        )
        let instance = AudifyPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Setup FFT event channel
        instance.fftEventChannel = FlutterEventChannel(
            name: "audify/fft",
            binaryMessenger: registrar.messenger()
        )
        instance.fftStreamHandler = AudioStreamHandler()
        instance.fftEventChannel?.setStreamHandler(instance.fftStreamHandler)
        
        // Setup waveform event channel
        instance.waveformEventChannel = FlutterEventChannel(
            name: "audify/waveform",
            binaryMessenger: registrar.messenger()
        )
        instance.waveformStreamHandler = AudioStreamHandler()
        instance.waveformEventChannel?.setStreamHandler(instance.waveformStreamHandler)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            let args = call.arguments as? [String: Any]
            let audioSessionId = args?["audioSessionId"] as? Int ?? 0
            let requestedCaptureSize = args?["captureSize"] as? Int ?? captureSize
            initialize(
                audioSessionId: audioSessionId,
                captureSize: requestedCaptureSize,
                result: result
            )
        case "setCaptureSize":
            if let args = call.arguments as? [String: Any],
               let captureSize = (args["captureSize"] ?? args["size"]) as? Int {
                setCaptureSize(captureSize: captureSize, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "captureSize is required", details: nil))
            }
        case "startCapture":
            startCapture(result: result)
        case "stopCapture":
            stopCapture(result: result)
        case "release":
            release(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initialize(audioSessionId: Int, captureSize: Int, result: @escaping FlutterResult) {
        do {
            guard !isCapturing else {
                result(FlutterError(
                    code: "CAPTURE_ACTIVE",
                    message: "Stop capture before reinitializing the visualizer",
                    details: nil
                ))
                return
            }
            guard captureSize > 0 else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "captureSize must be greater than zero",
                    details: nil
                ))
                return
            }
            self.captureSize = captureSize
            
            // Setup audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            // Initialize audio engine
            audioEngine = AVAudioEngine()
            
            // Setup FFT
            try setupFFT(captureSize: captureSize)
            
            result([
                "sampleRate": Int(audioSession.sampleRate.rounded()),
                "captureSize": self.captureSize
            ])
        } catch {
            result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func setupFFT(captureSize: Int) throws {
        // Create FFT setup for real-to-complex transform
        guard let newFftSetup = vDSP_DFT_zrop_CreateSetup(
            nil,
            vDSP_Length(captureSize),
            vDSP_DFT_Direction.FORWARD
        ) else {
            throw NSError(
                domain: "Audify",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create FFT resources"]
            )
        }

        // Create Hann window for FFT
        var newWindow = [Float](repeating: 0, count: captureSize)
        vDSP_hann_window(&newWindow, vDSP_Length(captureSize), Int32(vDSP_HANN_NORM))

        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
        self.fftSetup = newFftSetup
        window = newWindow
    }
    
    private func setCaptureSize(captureSize: Int, result: @escaping FlutterResult) {
        guard audioEngine != nil else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "Initialize the visualizer before changing the capture size",
                details: nil
            ))
            return
        }
        guard !isCapturing else {
            result(FlutterError(
                code: "CAPTURE_ACTIVE",
                message: "Stop capture before changing the capture size",
                details: nil
            ))
            return
        }
        guard captureSize > 0 else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "captureSize must be greater than zero",
                details: nil
            ))
            return
        }

        do {
            try setupFFT(captureSize: captureSize)
            self.captureSize = captureSize
            result(["captureSize": self.captureSize])
        } catch {
            result(FlutterError(code: "SET_SIZE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func startCapture(result: @escaping FlutterResult) {
        if isCapturing {
            result(true)
            return
        }

        guard let audioEngine = audioEngine else {
            result(FlutterError(code: "ENGINE_ERROR", message: "Audio engine not initialized", details: nil))
            return
        }
        
        do {
            let mainMixer = audioEngine.mainMixerNode
            let outputNode = audioEngine.outputNode
            let format = outputNode.inputFormat(forBus: 0)
            
            // Install tap on main mixer to capture audio
            mainMixer.installTap(onBus: 0, bufferSize: AVAudioFrameCount(captureSize), format: format) { [weak self] buffer, _ in
                guard let self = self else { return }
                self.processAudioBuffer(buffer: buffer)
            }
            
            try audioEngine.start()
            isCapturing = true
            result(true)
        } catch {
            // `installTap` succeeds before `audioEngine.start` can fail. Remove
            // it here so a later retry does not retain a stale tap.
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func stopCapture(result: @escaping FlutterResult) {
        if !isCapturing {
            result(true)
            return
        }

        guard let audioEngine = audioEngine else {
            result(false)
            return
        }
        
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        audioEngine.stop()
        isCapturing = false
        result(true)
    }
    
    private func release(result: @escaping FlutterResult) {
        if isCapturing {
            audioEngine?.mainMixerNode.removeTap(onBus: 0)
            audioEngine?.stop()
        }
        
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
            self.fftSetup = nil
        }
        
        audioEngine = nil
        isCapturing = false
        result(true)
    }
    
    private func processAudioBuffer(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        
        // Process waveform data
        processWaveform(samples: samples)
        
        // Process FFT data
        processFFT(samples: samples)
    }
    
    private func processWaveform(samples: [Float]) {
        // Convert Float samples to Android Visualizer-compatible unsigned
        // waveform bytes centered at 128.
        let waveformData: [UInt8] = samples.prefix(captureSize).map { sample in
            let clampedSample = max(-1.0, min(1.0, sample))
            let scaledSample: Float
            if clampedSample < 0 {
                scaledSample = (clampedSample * 128.0) + 128.0
            } else {
                scaledSample = (clampedSample * 127.0) + 128.0
            }
            return UInt8(max(0, min(255, Int(scaledSample.rounded()))))
        }
        
        waveformStreamHandler?.sendData(data: waveformData)
    }
    
    private func processFFT(samples: [Float]) {
        guard let fftSetup = fftSetup else { return }

        // The real DFT API packs the time-domain signal into separate vectors
        // containing its even and odd samples. Apply the window while filling
        // those vectors to avoid allocating intermediate sample buffers.
        let halfCaptureSize = captureSize / 2
        var inputReal = [Float](repeating: 0, count: halfCaptureSize)
        var inputImaginary = [Float](repeating: 0, count: halfCaptureSize)
        for i in 0..<halfCaptureSize {
            let realIndex = i * 2
            let imaginaryIndex = realIndex + 1

            if realIndex < samples.count {
                inputReal[i] = samples[realIndex] * window[realIndex]
            }
            if imaginaryIndex < samples.count {
                inputImaginary[i] = samples[imaginaryIndex] * window[imaginaryIndex]
            }
        }

        var realPart = [Float](repeating: 0, count: halfCaptureSize)
        var imagPart = [Float](repeating: 0, count: halfCaptureSize)

        // Perform the real-to-complex transform.
        vDSP_DFT_Execute(
            fftSetup,
            &inputReal,
            &inputImaginary,
            &realPart,
            &imagPart
        )
        
        // Convert to Android Visualizer FFT format:
        // [real0, realNyquist, real1, imag1, real2, imag2, ...].
        var fftData = [UInt8](repeating: 0, count: captureSize)
        // vDSP's forward real DFT is unnormalized, so scale it back to a
        // signed 8-bit visualization range before sending it to Dart.
        let frequencyScale = 127.0 / Float(captureSize)
        func fftByte(_ value: Float) -> UInt8 {
            let scaledValue = value * frequencyScale
            let byteValue = Int8(max(-128, min(127, scaledValue)))
            return UInt8(bitPattern: byteValue)
        }

        // The real-input DFT stores the Nyquist component in imagPart[0].
        fftData[0] = fftByte(realPart[0])
        fftData[1] = fftByte(imagPart[0])

        // Copy interleaved real and imaginary parts for positive-frequency bins.
        for i in 1..<captureSize / 2 {
            fftData[2 * i] = fftByte(realPart[i])
            fftData[(2 * i) + 1] = fftByte(imagPart[i])
        }
        
        fftStreamHandler?.sendData(data: fftData)
    }
}

// Stream handler for audio data
class AudioStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    func sendData(data: [UInt8]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(FlutterStandardTypedData(bytes: Data(data)))
        }
    }
}
