//
//  AudioEngine.swift
//  just_audio
//
//  Created by Steve Myers on 3/22/21.
//

import Foundation
import AVFoundation
import MediaPlayer

class AudioEnginePlayer {
    
    let engine = AVAudioEngine()
    let tempoControl = AVAudioUnitTimePitch()
    let audioPlayer = AVAudioPlayerNode()
    
    let musicPlayer = MPMusicPlayerApplicationController.applicationQueuePlayer
    
    init() {
        NSLog("HEY MAN")
        engine.attach(audioPlayer)
        engine.attach(tempoControl)

        engine.connect(audioPlayer, to: tempoControl, format: nil)
        engine.connect(tempoControl, to: engine.mainMixerNode, format: nil)
        
        let songs = MPMediaQuery.songs()
        guard let song = songs.items?[0].assetURL else {
            return
        }
        
        do {
            try load(url: song)
            try play()
        } catch {
            print("bleh")
        }
        
        
        
    }
    
    deinit {
        engine.stop()
    }
    
    func load(urlString: String) throws {

        /*let file = try AVAudioFile(forReading: url)
        let audioPlayer = AVAudioPlayerNode()
        audioPlayer.scheduleFile(file, at: nil)*/

    }
    
    func load (url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        audioPlayer.scheduleFile(file, at: nil)
        
    }
    
    func play() throws {
       
        try engine.start()
        audioPlayer.play()
    }
    
    func pause() {
        audioPlayer.pause()
        engine.pause()
    }
}
