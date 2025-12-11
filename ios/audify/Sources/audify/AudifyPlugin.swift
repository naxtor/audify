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
            if let args = call.arguments as? [String: Any],
               let audioSessionId = args["audioSessionId"] as? Int {
                initialize(audioSessionId: audioSessionId, result: result)
            } else {
                initialize(audioSessionId: 0, result: result)
            }
        case "setCaptureSize":
            if let args = call.arguments as? [String: Any],
               let size = args["size"] as? Int {
                setCaptureSize(size: size, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "size is required", details: nil))
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
    
    private func initialize(audioSessionId: Int, result: @escaping FlutterResult) {
        do {
            // Setup audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            // Initialize audio engine
            audioEngine = AVAudioEngine()
            
            // Setup FFT
            setupFFT()
            
            result(true)
        } catch {
            result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func setupFFT() {
        // Create FFT setup for real-to-complex transform
        let log2n = vDSP_Length(log2(Float(captureSize)))
        fftSetup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(captureSize), vDSP_DFT_Direction.FORWARD)
        
        // Create Hann window for FFT
        window = [Float](repeating: 0, count: captureSize)
        vDSP_hann_window(&window, vDSP_Length(captureSize), Int32(vDSP_HANN_NORM))
    }
    
    private func setCaptureSize(size: Int, result: @escaping FlutterResult) {
        captureSize = size
        setupFFT()
        result(true)
    }
    
    private func startCapture(result: @escaping FlutterResult) {
        guard let audioEngine = audioEngine else {
            result(FlutterError(code: "ENGINE_ERROR", message: "Audio engine not initialized", details: nil))
            return
        }
        
        do {
            let mainMixer = audioEngine.mainMixerNode
            let outputNode = audioEngine.outputNode
            let format = outputNode.inputFormat(forBus: 0)
            
            // Install tap on main mixer to capture audio
            mainMixer.installTap(onBus: 0, bufferSize: AVAudioFrameCount(captureSize), format: format) { [weak self] (buffer, time) in
                guard let self = self else { return }
                self.processAudioBuffer(buffer: buffer)
            }
            
            try audioEngine.start()
            isCapturing = true
            result(true)
        } catch {
            result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func stopCapture(result: @escaping FlutterResult) {
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
        // Convert Float samples to Int8 for compatibility with Android format
        let waveformData: [Int8] = samples.prefix(captureSize).map { sample in
            Int8(max(-128, min(127, sample * 127)))
        }
        
        waveformStreamHandler?.sendData(data: waveformData)
    }
    
    private func processFFT(samples: [Float]) {
        guard let fftSetup = fftSetup else { return }
        
        var processedSamples = samples.prefix(captureSize).map { $0 }
        
        // Pad if necessary
        while processedSamples.count < captureSize {
            processedSamples.append(0)
        }
        
        // Apply window
        var windowedSamples = [Float](repeating: 0, count: captureSize)
        vDSP_vmul(processedSamples, 1, window, 1, &windowedSamples, 1, vDSP_Length(captureSize))
        
        // Prepare complex buffer
        var realPart = [Float](repeating: 0, count: captureSize / 2)
        var imagPart = [Float](repeating: 0, count: captureSize / 2)
        
        // Split real input into even/odd indices for complex FFT
        for i in 0..<captureSize / 2 {
            realPart[i] = windowedSamples[2 * i]
            imagPart[i] = windowedSamples[2 * i + 1]
        }
        
        var complexBuffer = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        
        // Perform FFT
        vDSP_DFT_Execute(fftSetup, &windowedSamples, &complexBuffer.realp!, &complexBuffer.imagp!)
        
        // Convert to Android Visualizer FFT format: [real0, real1, ..., realN/2, imag1, ..., imagN/2-1]
        var fftData = [Int8](repeating: 0, count: captureSize)
        
        // Copy real parts
        for i in 0..<captureSize / 2 {
            let value = Int8(max(-128, min(127, realPart[i] * 127)))
            fftData[i] = value
        }
        
        // Copy imaginary parts (skip DC and Nyquist)
        for i in 1..<captureSize / 2 {
            let value = Int8(max(-128, min(127, imagPart[i] * 127)))
            fftData[captureSize / 2 + i - 1] = value
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
    
    func sendData(data: [Int8]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}
