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
    private var updatePosition: Int64 = 0
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
            switch (call.method) {
            case "play":
                play(result)
            default:
                result(FlutterMethodNotImplemented);
            }
            
        } catch {
            let flutterError = FlutterError(code: "error", message: "Error in handleMethodCall", details: nil)
            result(flutterError)
        }
    }
    
    func play() {
        play(nil)
    }
    
    func play(_ result: FlutterResult?) {
        
    }
    
    func broadcastPlaybackEvent() {
        guard let sink = self.eventSink else {
            return
        }
        let event : [String : Any] = [
            "processingState": processingState.rawValue,
            "updatePosition": 1000 * updatePosition,
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
        return 0
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
        return Int64(duration < 0 ? -1 : Int64(1000) * duration)
    }
    
    func hasSources() -> Bool {
        //return indexedAudioSources && indexedAudioSources.count > 0
        return true
    }
    func dispose() {
        
    }
}
