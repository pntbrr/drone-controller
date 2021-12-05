//
//  PeerTalkManager.swift
//  DroneController
//
//  Created by Ponk on 05/12/2021.
//

import Foundation
import PeerTalk

struct PTTypes {
    struct Settings {
        static let port: in_port_t = 2345
    }
    enum Frame: UInt32 {
        case deviceInfo = 100
        case message = 101
        case ping = 102
        case pong = 103
    }
}

class PeerTalkManager: NSObject {
    
    var serverChannel: PTChannel?
    var peerChannel: PTChannel?
    
    private var connectCallback: ((PTAddress) -> ())?
    private var messageCallback: ((String) -> ())?
    
    static let instance = PeerTalkManager()
    
    private override init() {
        super.init()
        
        let channel = PTChannel(protocol: nil, delegate: self)
        channel.listen(on: PTTypes.Settings.port, IPv4Address: INADDR_LOOPBACK) { error in
            if let error = error {
                print("Failed to listen on 127.0.0.1:\(PTTypes.Settings.port) \(error)")
            } else {
                print("Listening on 127.0.0.1:\(PTTypes.Settings.port)")
                self.serverChannel = channel
            }
        }
    }
    
    func onConnect(cb: @escaping ((PTAddress) -> ())) {
        connectCallback = cb
    }
    
    func onMessage(cb: @escaping ((String) -> ())) {
        messageCallback = cb
    }
    
    func send(message: String) {
        if let peerChannel = peerChannel {
            var m = message
            let payload = m.withUTF8 { buffer -> Data in
                var data = Data()
                data.append(CFSwapInt32HostToBig(UInt32(buffer.count)).data)
                data.append(buffer)
                return data
            }
            peerChannel.sendFrame(type: PTTypes.Frame.message.rawValue, tag: 0, payload: payload, callback: nil)
        } else {
            print("Cannot send message - not connected")
        }
    }
}


extension PeerTalkManager: PTChannelDelegate {
    
    func channel(_ channel: PTChannel, didRecieveFrame type: UInt32, tag: UInt32, payload: Data?) {
        if let type = PTTypes.Frame(rawValue: type) {
            switch type {
            case .message:
                guard let payload = payload else {
                    return
                }
                payload.withUnsafeBytes { buffer in
                    let textBytes = buffer[(buffer.startIndex + MemoryLayout<UInt32>.size)...]
                    if let message = String(bytes: textBytes, encoding: .utf8) {
                        self.messageCallback?(message)
                    }
                }
            case .ping:
                peerChannel?.sendFrame(type: PTTypes.Frame.pong.rawValue, tag: 0, payload: nil, callback: nil)
            default:
                break
            }
        }
    }

    func channel(_ channel: PTChannel, shouldAcceptFrame type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        guard channel == peerChannel else {
            return false
        }
        guard let frame = PTTypes.Frame(rawValue: type),
                    frame == .ping || frame == .message else {
            print("Unexpected frame of type: \(type)")
            return false
        }
            return true
    }

    func channel(_ channel: PTChannel, didAcceptConnection otherChannel: PTChannel, from address: PTAddress) {
        peerChannel?.cancel()
        peerChannel = otherChannel
        peerChannel?.userInfo = address
        connectCallback?(address)
    }

    func channelDidEnd(_ channel: PTChannel, error: Error?) {
        if let error = error {
            print("\(channel) ended with \(error)")
        } else {
            print("Disconnected from \(channel.userInfo)")
        }
    }
}

extension FixedWidthInteger {
    var data: Data {
        var bytes = self
        return Data(bytes: &bytes, count: MemoryLayout.size(ofValue: self))
    }
}
