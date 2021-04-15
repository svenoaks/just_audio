//
//  AudioEngine.swift
//  just_audio
//
//  Created by Steve Myers on 3/22/21.
//

import Foundation
import AVFoundation
import MediaPlayer
import Flutter

extension AVAudioFile {
    
    var duration: Int64 {
        let sampleRateSong = Double(processingFormat.sampleRate)
        let lengthSongSeconds = Double(length) / sampleRateSong
        return Int64(lengthSongSeconds * 1000)
    }
}

extension AVAudioPlayerNode {
    var currentPosition: Int64 {
        if let nodeTime = lastRenderTime, let playerTime = playerTime(forNodeTime: nodeTime) {
            return samplesToTimeMs(samples: Double(playerTime.sampleTime), sampleRate: playerTime.sampleRate)
        }
        return 0
    }
}

func samplesToTimeMs(samples: Double, sampleRate: Double) -> Int64 {
    return Int64(samples / sampleRate) * 1000
}

protocol AudioEngineListener: class {
    func onTrackComplete()
    func onUpdatePosition()
}

class AudioEnginePlayer {
    let test = true
    
    let engine = AVAudioEngine()
    let tempoControl = AVAudioUnitTimePitch()
    let audioPlayer = AVAudioPlayerNode()
    
    var audioFile: AVAudioFile?
    var repeatMode = AudioPlayer.LoopMode.loopOff
    var shuffleMode = false
    
    var duration: Int64 {
        audioFile?.duration ?? -1
    }
    
    var currentPosition: Int64 {
        guard let file = audioFile else { return 0; }
        print(audioPlayer.outputPresentationLatency)
        return audioPlayer.currentPosition + seekPosition - samplesToTimeMs(samples: Double(accumulatedLoopSamples), sampleRate: file.processingFormat.sampleRate)
    }
    
    var isPlaying: Bool {
        audioPlayer.isPlaying
    }
    
    var seekPosition: Int64 = 0 //ms
    var seeking = false
    
    private var _abLoopPoints: AudioPlayer.ABLoopPoints = .init(nil, nil)
    
    var isLooping: Bool {
        return abLoopPoints.pointA != nil && abLoopPoints.pointB != nil
    }
    
    var abLoopPoints: AudioPlayer.ABLoopPoints {
        get {
            return _abLoopPoints;
        }
        set(value) {
            let newLoop = _abLoopPoints.pointA != value.pointA || _abLoopPoints.pointB != value.pointB
            _abLoopPoints = value
            if newLoop && isLooping {
                startLoop()
            }
        }
    }
    
    var lastLoopStartSamples: UInt32?
    var lastLoopLengthSamples: UInt32?
    
    var accumulatedLoopSamples: UInt32 = 0
    
    weak var listener: AudioEngineListener?
    
    init() {
        engine.attach(audioPlayer)
        engine.attach(tempoControl)
        
        engine.connect(audioPlayer, to: tempoControl, format: nil)
        engine.connect(tempoControl, to: engine.mainMixerNode, format: nil)
    }
    
    func firstLibraryURL() -> URL? {
        let songs = MPMediaQuery.songs()
        let song = songs.items?[0]
        let filtered = songs.items?.first(where: { (item: MPMediaItem) -> Bool in
            item.assetURL != nil
        })
        let title = filtered?.title ?? "no title"
        NSLog(title)
        return filtered?.assetURL
    }
    
    func assetsURL(registrar: FlutterPluginRegistrar) -> URL? {
        NSLog("assetsURL")
        let key = registrar.lookupKey(forAsset: "assets/audio/out.mp3")
        let path = Bundle.main.path(forResource: key, ofType: nil)
        return URL(fileURLWithPath: path!)
    }
    
    
    deinit {
        engine.stop()
    }
    
    
    var speed: Double {
        get {
            return Double(tempoControl.rate)
        }
        set(value) {
            tempoControl.rate = Float(value)
            listener?.onUpdatePosition()
        }
    }
    var pitch: Double {
        get {
            return Double(tempoControl.pitch)
        }
        set(value) {
            tempoControl.pitch = Float(value)
            listener?.onUpdatePosition()
        }
    }
    
    
    func stopAndScheduleSegment(startTimeUs: CMTime) {
        guard let file = audioFile else { return }
        let wasPlaying = audioPlayer.isPlaying
        audioPlayer.stop()
        
        let (startSample, lengthSamples) = startAndLengthSamples(file: file, startTimeUs: startTimeUs, endSamples: UInt32(file.length))
        
        if lengthSamples > 0 {
            scheduleSegment(startSample: startSample, lengthSamples: lengthSamples, completionType: .dataPlayedBack, loop: false)
        } else {
            regularCompletionHandler(type: .dataPlayedBack)
        }
        
        seekPosition = startTimeUs.value / 1000
        accumulatedLoopSamples = 0
        if (wasPlaying) {
            audioPlayer.play()
        }
    }
    
    func startLoop(offsetSamples: UInt32 = 0) {
        guard let file = audioFile, let pointA = abLoopPoints.pointA, let pointB = abLoopPoints.pointB else { return }
        seeking = true
        let endSamples = timeToSamples(file: file, timeUs: pointB)
        (lastLoopStartSamples, lastLoopLengthSamples) = startAndLengthSamples(file: file, startTimeUs: pointA, endSamples: endSamples)
        let startSamples = lastLoopStartSamples! + offsetSamples
        let lengthSamples = lastLoopLengthSamples! - offsetSamples
        let wasPlaying = audioPlayer.isPlaying
        audioPlayer.stop()
        scheduleSegment(startSample: startSamples, lengthSamples: lengthSamples, completionType: .dataRendered, loop: true)
        seekPosition = pointA.value / 1000 + samplesToTimeMs(samples: Double(offsetSamples), sampleRate: file.processingFormat.sampleRate)
        accumulatedLoopSamples = 0
        if (wasPlaying) {
            audioPlayer.play()
        }
        listener?.onUpdatePosition()
    }
    
    func timeToSamples(file: AVAudioFile, timeUs: CMTime) -> UInt32 {
        let startInSongSeconds = timeUs.seconds
        return UInt32(floor(startInSongSeconds * file.processingFormat.sampleRate))
    }
    
    func startAndLengthSamples(file: AVAudioFile, startTimeUs: CMTime, endSamples: UInt32) -> (startSample: UInt32, lengthSamples: UInt32) {
        let startSample = timeToSamples(file: file, timeUs: startTimeUs)
        let lengthSamples: UInt32 = endSamples - startSample
        return (startSample, lengthSamples)
    }
    
    func regularCompletionHandler(type: AVAudioPlayerNodeCompletionCallbackType) {
        DispatchQueue.main.async { [weak self] in
            guard let sel = self else { return; }
            if (!(sel.seeking)) {
                switch (sel.repeatMode) {
                case AudioPlayer.LoopMode.loopOne:
                    sel.stopAndScheduleSegment(startTimeUs: .zero)
                case AudioPlayer.LoopMode.loopOff:
                    break;
                case AudioPlayer.LoopMode.loopAll:
                    sel.stopAndScheduleSegment(startTimeUs: .zero)
                case AudioPlayer.LoopMode.loopStop:
                    break;
                }
                sel.listener?.onTrackComplete()
            }
            sel.seeking = false
        }
    }
    
    func loopCompletionHandler (type: AVAudioPlayerNodeCompletionCallbackType) {
        DispatchQueue.main.async { [weak self] in
            guard let sel = self, let startSamples = sel.lastLoopStartSamples, let lengthSamples = sel.lastLoopLengthSamples else { return }
            if (!(sel.seeking)) {
                if let _ = sel.abLoopPoints.pointA, let _ = sel.abLoopPoints.pointB {
                    sel.scheduleSegment(startSample: startSamples, lengthSamples: lengthSamples, completionType: .dataRendered, loop: true)
                    sel.accumulatedLoopSamples += lengthSamples
                    sel.listener?.onUpdatePosition()
                } else {
                    guard let file = sel.audioFile else { return }
                    let newStart: UInt32 = startSamples + lengthSamples
                    let newLength: UInt32 = UInt32(file.length) - newStart
                    sel.scheduleSegment(startSample: newStart, lengthSamples: newLength, completionType: .dataPlayedBack, loop: false)
                }
            }
            sel.seeking = false
        }
    }
    
    func scheduleSegment(startSample: UInt32, lengthSamples: UInt32, completionType: AVAudioPlayerNodeCompletionCallbackType, loop: Bool) {
        guard let file = audioFile else { return }
        audioPlayer.scheduleSegment(file,
                                    startingFrame: AVAudioFramePosition(startSample),
                                    frameCount: AVAudioFrameCount(lengthSamples), at: nil,
                                    completionCallbackType: completionType,
                                    completionHandler: loop ? loopCompletionHandler : regularCompletionHandler
        )
    }
    
    
    func load (_ urlString: String, _ initialPosition: CMTime, registrar: FlutterPluginRegistrar? = nil) throws -> Int64 {
        try engine.start()
        
        if (test) {
            guard let reg = registrar, let songUrl = assetsURL(registrar: reg) else {
                return -1
            }
            return try load(url: songUrl, initialPosition: initialPosition)
            
        } else {
            return try load(url: URL(fileURLWithPath: urlString), initialPosition: initialPosition)
        }
    }
    
    func seek(_ pos: CMTime) { //Microseconds
        guard let file = audioFile else { return; }
        seeking = true
        if (isLooping) {
            var offsetSamples: UInt32 = 0
            if (pos > _abLoopPoints.pointA! && pos < _abLoopPoints.pointB!) {
                offsetSamples = timeToSamples(file: file, timeUs: pos) - lastLoopStartSamples!
            }
            startLoop(offsetSamples: offsetSamples)
        } else {
            stopAndScheduleSegment(startTimeUs: pos)
        }
    }
    
    
    
    private func load (url: URL, initialPosition: CMTime) throws -> Int64 {
        audioFile = try AVAudioFile(forReading: url)
        stopAndScheduleSegment(startTimeUs: .zero)
        return duration
    }
    
    func play() {
        audioPlayer.play()
    }
    
    func pause() {
        audioPlayer.pause()
        //engine.pause()
    }
}
