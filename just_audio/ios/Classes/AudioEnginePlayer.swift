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
        if let nodeTime = lastRenderTime,let playerTime = playerTime(forNodeTime: nodeTime) {
            return Int64((Double(playerTime.sampleTime) / playerTime.sampleRate) * 1000)
        }
        return 0
    }
}

class AudioEnginePlayer {
    
    let engine = AVAudioEngine()
    let tempoControl = AVAudioUnitTimePitch()
    let audioPlayer = AVAudioPlayerNode()
    
    var audioFile: AVAudioFile?
    
    var duration: Int64 {
        audioFile?.duration ?? -1
    }
    
    var currentPosition: Int64 {
        audioPlayer.currentPosition
    }
    
    init() {
        engine.attach(audioPlayer)
        engine.attach(tempoControl)
                
        engine.connect(audioPlayer, to: tempoControl, format: nil)
        engine.connect(tempoControl, to: engine.mainMixerNode, format: nil)
    }
    
    func testURL() -> URL? {
        let songs = MPMediaQuery.songs()
        let song = songs.items?[0]
        let filtered = songs.items?.first(where: { (item: MPMediaItem) -> Bool in
            item.assetURL != nil
        })
        let title = filtered?.title ?? "no title"
        NSLog(title)
        return filtered?.assetURL
    }
    
    deinit {
        engine.stop()
    }
    
    func load(_ urlString: String) throws -> Int64 {
        guard let songUrl = testURL() else {
            return -1
        }
        try engine.start()
        return try load(url: songUrl)
        
        return try load(url: URL(fileURLWithPath: urlString))
    }
    
    func seek(_ pos: CMTime) { //Microseconds
        guard let file = audioFile else { return }
        audioPlayer.stop()
        let startInSongSeconds = Double(pos.value) / 1000000.0 // example
        let startSample = UInt32(floor(startInSongSeconds * file.processingFormat.sampleRate))
        let lengthSamples: UInt32 = UInt32(file.length) - startSample
        

        audioPlayer.scheduleSegment(file, startingFrame: AVAudioFramePosition(startSample), frameCount: AVAudioFrameCount(lengthSamples), at: nil, completionHandler: {
            // do something (pause player)
        })
        audioPlayer.play()
    }
    
    func load (url: URL) throws -> Int64 {
        audioFile = try AVAudioFile(forReading: url)
        audioPlayer.scheduleFile(audioFile!, at: nil)
        return duration
    }
    
    func play() throws {
        audioPlayer.play()
    }
    
    func pause() {
        audioPlayer.pause()
        //engine.pause()
    }
}
