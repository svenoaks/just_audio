import Flutter
import UIKit

public class SwiftJustAudioPlugin: NSObject, FlutterPlugin {
    private weak var registrar: FlutterPluginRegistrar?
    private var players: [String : AudioPlayer] = [:]
    
    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }
    public class func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.ryanheise.just_audio.methods",
            binaryMessenger: registrar.messenger())
        
        let instance = SwiftJustAudioPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if "init" == call.method {
            let request = call.arguments as! Dictionary<String, String>
            let playerId = request["id"]
            if players[playerId ?? ""] != nil {
                let flutterError = FlutterError(code: "error", message: "Platform player already exists", details: nil)
                result(flutterError)
            } else {
                guard let reg = registrar, let id = playerId else {
                    let flutterError = FlutterError(code: "error", message: "registrar or playerId nil", details: nil)
                    result(flutterError)
                    return
                }
                let player = AudioPlayer(registrar: reg, id: id)
                players[playerId ?? ""] = player
                result(nil)
            }
        } else if "disposePlayer" == call.method {
            let request = call.arguments as! Dictionary<String, String>
            let playerId = request["id"]
            players[playerId ?? ""] = nil
            result([:])
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    deinit {
        /*players.forEach { (id, player) in
            player.dispose()
        }
        players.removeAll()*/
    }
    
}
