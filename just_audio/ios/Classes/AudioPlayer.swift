//
//  AudioPlayer.swift
//  just_audio
//
//  Created by Steve Myers on 3/21/21.
//

import Foundation
import Flutter
import AVFoundation

class AudioPlayer: NSObject, FlutterStreamHandler {
    
    enum ProcessingState : Int {
        case none
        case loading
        case buffering
        case ready
        case completed
    }
    
    
    enum LoopMode : Int {
        case loopOff
        case loopOne
        case loopAll
    }
    
    private weak var registrar: FlutterPluginRegistrar?
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private let playerId: String
    private let player: AudioEnginePlayer
    //private var player: AVQueuePlayer?
    //private var audioSource: AudioSource?
    //private var indexedAudioSources: [IndexedAudioSource]?
    private var order: [NSNumber]?
    private var orderInv: [NSNumber]?
    private var index = 0
    private var processingState: ProcessingState!
    //private var loopMode: LoopMode!
    private var shuffleModeEnabled = false
    private var updateTime: Int64 = 0
    private var updatePos: Int64 = 0
    private var lastPosition: Int64 = 0
    private var bufferedPosition: Int64 = 0
    
    private var bufferUnconfirmed = false
    private var seekPos: CMTime!
    private var initialPos: CMTime!
    private var loadResult: FlutterResult?
    private var playResult: FlutterResult?
    private var timeObserver: Any?
    private var automaticallyWaitsToMinimizeStalling = false
    private var playing = false
    private var speed: Float = 0.0
    private var justAdvanced = false
    private var icyMetadata: [String : NSObject] = [:]
    
    init(registrar: FlutterPluginRegistrar, id: String) {
        self.registrar = registrar
        self.playerId = id
        methodChannel = FlutterMethodChannel(
            name: "com.ryanheise.just_audio.methods.\(id)",
            binaryMessenger: registrar.messenger())
        eventChannel = FlutterEventChannel(
            name: "com.ryanheise.just_audio.events.\(id)",
            binaryMessenger: registrar.messenger())
        player = AudioEnginePlayer()
        super.init()
        methodChannel.setMethodCallHandler({ [weak self] call, result in
            self?.handle(call, result: result)
        })
        
        eventChannel.setStreamHandler(self)
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    var a = 0
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            let request = call.arguments as! [AnyHashable : Any]
            switch (call.method) {
            case "load":
                NSLog("load called")
                let ip: Int64 = request["initialPosition"] as? Int64 ?? 0
                let initialIndex: Int = request["initialIndex"] as? Int ?? 0
                let audioSource = (request["audioSource"] as! [String: Any])["id"]
                let initialPosition: CMTime = CMTimeMake(value: ip, timescale: 1000000)
                if let aSource = audioSource as? String {
                    load(audioSource: aSource, initialPosition: initialPosition, initialIndex: initialIndex, result: result)
                }
            case "play":
                NSLog("play called")
                play(result)
            case "pause":
                NSLog("paused called")
                pause()
                result([:])
            case "setVolume":
                NSLog("setVolume called")
                result([:])
            case "setSpeed":
                result([:])
            case "setLoopMode":
                result([:])
            case "setShuffleMode":
                result([:])
            case "automaticallyWaitsToMinimizeStalling":
                result([:])
            case "seek":
                let ip = request["position"] as? Int64
                let position = ip == nil ? CMTime.positiveInfinity : CMTimeMake(value: ip!, timescale: 1000000)
                seek(position)
                result([:])
            case "concatenatingInsertAll":
                result([:])
            case "concatenatingRemoveRange":
                result([:])
            case "concatenatingMove":
                result([:])
            case "setAndroidAudioAttributes":
                result([:])
            default:
                result(FlutterMethodNotImplemented);
            }
            
        } catch {
            let flutterError = FlutterError(code: "error", message: "Error in handleMethodCall", details: nil)
            result(flutterError)
        }
    }
    
    func seek(_ pos: CMTime) {
        if processingState == ProcessingState.none || processingState == ProcessingState.loading {
            return
        }
        player.seek(pos)
        
    }
    
    func load(audioSource: String, initialPosition: CMTime, initialIndex: Int, result: @escaping FlutterResult) {
        NSLog("load internal called")
        loadResult = result
        processingState = ProcessingState.loading
        do {
            let durationMs = try player.load(audioSource)
            let durationUs = durationMs * 1000
            NSLog("duration: \(durationUs)")
            processingState = ProcessingState.ready
            result(["duration": durationUs])
        } catch {
            processingState = ProcessingState.none
            result(["duration": -1])
        }
        loadResult = nil
    }
    
    func pause() {
        if !playing {
            return
        }
        playing = false
        player.pause()
        updatePosition()
        broadcastPlaybackEvent()
        if let pr = playResult {
            //NSLog(@"PLAY FINISHED DUE TO PAUSE");
            pr([:])
            playResult = nil
        }
    }
    
    func play() {
        play(nil)
    }
    
    func play(_ result: FlutterResult?) {
        if (playing) {
            result?([:])
            return
        }
        if let res = result {
            playResult?([:])
            playResult = res
        }
        playing = true
        do {
            try player.play()
        } catch {
            //TODO handle
        }
        //TODO player.rate = speed
        updatePosition()
        
    }
    
    func broadcastPlaybackEvent() {
        guard let sink = self.eventSink else {
            return
        }
        let event : [String : Any] = [
            "processingState": processingState.rawValue,
            "updatePosition": 1000 * updatePos,
            "updateTime": updateTime,
            "bufferedPosition": 1000 * getBufferedPosition(),
            "icyMetadata": icyMetadata,
            "duration": getDurationMicroseconds(),
            "currentIndex": index
        ]
        sink(event)
    }
    func getBufferedPosition() -> Int64 {
        return 0
        /*if processingState == ProcessingState.none || processingState == ProcessingState.loading {
            return 0
        } else if hasSources() {
            var ms = Int(1000 * CMTimeGetSeconds(indexedAudioSources[index].bufferedPosition))
            if ms < 0 {
                ms = 0
            }
            return ms
        } else {
            return 0
        }*/
    }
    
    func getDuration() -> Int64 {
        return player.duration
        /*if processingState == none || processingState == loading {
            return -1
        } else if indexedAudioSources && indexedAudioSources.count > 0 {
            let v = Int(1000 * CMTimeGetSeconds(indexedAudioSources[index].duration))
            return v
        } else {
            return 0
        }*/
    }
    
    func getDurationMicroseconds() -> Int64 {
        let duration = getDuration()
        return Int64(duration < 0 ? -1 : 1000 * duration)
    }
    
    func updatePosition() {
        updatePos = getCurrentPosition()
        updateTime = Int64(Date().timeIntervalSince1970 * 1000.0)
    }
    func hasSources() -> Bool {
        //return indexedAudioSources && indexedAudioSources.count > 0
        return true
    }
    
    func getCurrentPosition() -> Int64 {
        return 0
        /*if processingState == ProcessingState.none || processingState == ProcessingState.loading {
            return Int(1000 * CMTimeGetSeconds(initialPos))
        } else if CMTIME_IS_VALID(seekPos) {
            return Int(1000 * CMTimeGetSeconds(seekPos))
        } else if hasSources() {
            var ms = Int(1000 * CMTimeGetSeconds(indexedAudioSources[index].position))
            if ms < 0 {
                ms = 0
            }
            return ms
        } else {
            return 0
        }*/
    }
    func dispose() {
        
    }
}
