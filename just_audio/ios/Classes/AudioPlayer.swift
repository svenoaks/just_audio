//
//  AudioPlayer.swift
//  just_audio
//
//  Created by Steve Myers on 3/21/21.
//

import Foundation
import Flutter
import AVFoundation

class AudioPlayer {
    private weak var registrar: (NSObjectProtocol & FlutterPluginRegistrar)?
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
    }
    func dispose() {
        
    }
}
