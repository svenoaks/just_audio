//
//  AudioEngine.swift
//  just_audio
//
//  Created by Steve Myers on 3/22/21.
//

import Foundation
import AVFoundation
import MediaPlayer

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
            let pos = Int64(((Double(playerTime.sampleTime) / playerTime.sampleRate)) * 1000)
            NSLog("pos: \(pos)")
            return pos > 0 ? pos : 0
        }
        NSLog("returning 0")
        return 0
    }
}

protocol AudioEngineListener: class {
    func onTrackComplete()
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
        audioPlayer.currentPosition + seekPosition
    }
    
    var isPlaying: Bool {
        audioPlayer.isPlaying
    }
    
    var seekPosition: Int64 = 0
    var seeking = false
    
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
    
    func setSpeed(_ speed: Double) {
        tempoControl.rate = Float(speed)
    }
    
    func setPitch(_ pitch: Double) {
        tempoControl.pitch = Float(pitch)
    }
    
    
    func stopAndScheduleSegment(startTimeUs: CMTime) {
        guard let file = audioFile else { return }
        let wasPlaying = audioPlayer.isPlaying
        audioPlayer.stop()
        let startInSongSeconds = startTimeUs.seconds
        let startSample = UInt32(floor(startInSongSeconds * file.processingFormat.sampleRate))
        let lengthSamples: UInt32 = UInt32(file.length) - startSample
        
        if lengthSamples > 0 {
            scheduleSegment(startSample: startSample, lengthSamples: lengthSamples, completionType: .dataConsumed)
        } else {
            completionHandler(type: .dataConsumed)
        }
        
        seekPosition = startTimeUs.value / 1000
        if (wasPlaying) {
            audioPlayer.play()
        }
        
    }
    
    func completionHandler(type: AVAudioPlayerNodeCompletionCallbackType) {
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
    
    func scheduleSegment(startSample: UInt32, lengthSamples: UInt32, completionType: AVAudioPlayerNodeCompletionCallbackType) {
        guard let file = audioFile else { return }
        audioPlayer.scheduleSegment(file,
                                    startingFrame: AVAudioFramePosition(startSample),
                                    frameCount: AVAudioFrameCount(lengthSamples), at: nil,
                                    completionCallbackType: completionType,
                                    completionHandler: completionHandler
        )
    }
    
    
    func load(_ urlString: String, _ initialPosition: CMTime, registrar: FlutterPluginRegistrar? = nil) throws -> Int64 {
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
        seeking = true
        stopAndScheduleSegment(startTimeUs: pos)
    }
    
    
    
    func load (url: URL, initialPosition: CMTime) throws -> Int64 {
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
