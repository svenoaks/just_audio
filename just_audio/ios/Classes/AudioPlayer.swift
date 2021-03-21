//
//  AudioPlayer.swift
//  just_audio
//
//  Created by Steve Myers on 3/21/21.
//

import Foundation
import Flutter
import AVFoundation

class AudioPlayer: NSObject {
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
    private var methodChannel: FlutterMethodChannel
    private var eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private var playerId: String
    private var player: AVQueuePlayer?
    //private var audioSource: AudioSource?
    //private var indexedAudioSources: [IndexedAudioSource]?
    private var order: [NSNumber]?
    private var orderInv: [NSNumber]?
    private var index = 0
    private var processingState: ProcessingState!
    //private var loopMode: LoopMode!
    private var shuffleModeEnabled = false
    private var updateTime: Int64 = 0
    private var updatePosition = 0
    private var lastPosition = 0
    private var bufferedPosition = 0
    
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
    private var icyMetadata: [String : NSObject]?
    
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
        //eventChannel.setStreamHandler( self)
    }
    func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    }
    func dispose() {
        
    }
}
