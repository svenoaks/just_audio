//
//  AudioPlayer.swift
//  just_audio
//
//  Created by Steve Myers on 3/21/21.
//

import Foundation
import Flutter
import AVFoundation

class AudioPlayer: NSObject, FlutterStreamHandler, AudioEngineListener {
    
    func onTrackComplete() {
        NSLog(player.isPlaying.description)
        if (player.repeatMode == .loopOff || player.repeatMode == .loopStop) {
            processingState = .completed
        }
        updatePosition()
        broadcastPlaybackEvent()
    }
    
    
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
        case loopStop
    }
    
    private weak var registrar: FlutterPluginRegistrar?
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private let playerId: String
    private let player: AudioEnginePlayer

    private var processingState = ProcessingState.none

    private var updateTime: Int64 = 0
    private var updatePos: Int64 = 0
 
    private var loadResult: FlutterResult?
    private var playResult: FlutterResult?
    
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
        player.listener = self
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
                play()
                result([:])
            case "pause":
                NSLog("paused called")
                pause()
                result([:])
            case "setVolume":
                NSLog("setVolume called")
                result([:])
            case "setSpeed":
                let speed = request["speed"] as! Double
                player.setSpeed(speed)
                result([:])
            case "setPitch":
                let pitch = request["pitch"] as! Double
                player.setPitch(pitch)
                result([:])
            case "setLoopMode":
                let loopMode: LoopMode = LoopMode(rawValue: request["loopMode"] as! Int)!
                player.repeatMode = loopMode
                result([:])
            case "setShuffleMode":
                player.shuffleMode = request["shuffleMode"] as! Int == 1
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
        if processingState == .none || processingState == .loading {
            return
        }
        if processingState == .completed {
            processingState = .ready
        }
        player.seek(pos)
        updatePosition()
        broadcastPlaybackEvent()
    }
    
    func load(audioSource: String, initialPosition: CMTime, initialIndex: Int, result: @escaping FlutterResult) {
        NSLog("load internal called")
        processingState = ProcessingState.loading
        do {
            let durationMs = try player.load(audioSource, initialPosition, registrar: registrar)
            let durationUs = durationMs * 1000
            NSLog("duration: \(durationUs)")
            processingState = ProcessingState.ready
            result(["duration": durationUs])
        } catch {
            processingState = ProcessingState.none
            result(["duration": -1])
        }
        updatePosition()
        broadcastPlaybackEvent()
    }
    
    func pause() {
        let playing = player.isPlaying
        if !playing {
            return
        }
        updatePosition()
        player.pause()
        broadcastPlaybackEvent()
        if let pr = playResult {
            //NSLog(@"PLAY FINISHED DUE TO PAUSE");
            pr([:])
            playResult = nil
        }
    }
    
    func play() {
        if (player.isPlaying) {
            return
        }
        player.play()
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
            "bufferedPosition": 1000 * updatePos,
            "icyMetadata": [:],
            "duration": getDurationMicroseconds(),
            "currentIndex": 0
        ]
        sink(event)
    }
   
    func getDuration() -> Int64 {
        return player.duration
    }
    
    func getDurationMicroseconds() -> Int64 {
        let duration = getDuration()
        return Int64(duration < 0 ? -1 : 1000 * duration)
    }
    
    func updatePosition() {
        updatePos = getCurrentPosition()
        updateTime = Int64(Date().timeIntervalSince1970 * 1000.0)
    }
    
    func getCurrentPosition() -> Int64 {
        return player.currentPosition
    }
    func dispose() {
        
    }
}
