//
//  StreamerVM.swift
//  MultipeerVideo-Assignment
//
//  Created by cleanmac on 16/01/23.
//

import MultipeerConnectivity
import UIKit
import AVKit
import CoreMotion

final class StreamerVM: NSObject, ObservableObject {
    private let motionManager: CMMotionManager
    private let motionQueue: OperationQueue
    private let serviceType = "video-peer"
    private let peerId = MCPeerID(displayName: UIDevice.current.name)
    private let peerAdvertiser: MCNearbyServiceAdvertiser
    private let peerSession: MCSession
    private weak var viewController: StreamerVC?
    
    let fileUrl = FileManager.default.urls(for: .documentDirectory,
                                           in: .userDomainMask)[0]
        .appendingPathComponent("output.mov")
    
    @Published private(set) var connectedPeer: MCPeerID? = nil
    @Published private(set) var recordingState: RecordingState = .notRecording
    @Published private(set) var videoOrientation: AVCaptureVideoOrientation = .portrait
    
    init(viewController: StreamerVC) {
        motionManager = CMMotionManager()
        motionQueue = OperationQueue()
        
        peerSession = MCSession(peer: peerId,
                                securityIdentity: nil,
                                encryptionPreference: .none)
        peerAdvertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: nil, serviceType: serviceType)
        
        self.viewController = viewController
        
        super.init()
        
        peerSession.delegate = self
        peerAdvertiser.delegate = self
        peerAdvertiser.startAdvertisingPeer()
        
        setupDeviceOrientationObserver()
    }
    
    deinit {
        peerAdvertiser.stopAdvertisingPeer()
        motionManager.stopAccelerometerUpdates()
    }
    
    private func setupDeviceOrientationObserver() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.accelerometerUpdateInterval = 1
            motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] acc, error in
                if let acceleration = acc?.acceleration {
                    var orientation: AVCaptureVideoOrientation
                    
                    if acceleration.x >= 0.75 {
                        orientation = .landscapeLeft
                    } else if acceleration.x <= -0.75 {
                        orientation = .landscapeRight
                    } else if acceleration.y <= -0.75 {
                        orientation = .portrait
                    } else if acceleration.y >= 0.75 {
                        orientation = .portraitUpsideDown
                    } else {
                        orientation = .portrait
                    }
                    
                    if orientation != self?.videoOrientation {
                        self?.videoOrientation = orientation
                    }
                }
            }
        }
    }
    
    func changeRecordingState(_ state: RecordingState) {
        recordingState = state
    }
    
    func showVideoPlayer(using videoUrl: URL) {
        let player = AVPlayer(url: videoUrl)
        let vc = AVPlayerViewController()
        vc.player = player
        viewController?.present(vc, animated: true) {
            player.play()
        }
    }
    
    func showSendDataModal(videoUrl: URL) {
        let alert = UIAlertController(title: "Send video",
                                      message: "Do you want to send this video to your host?",
                                      preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "Yes", style: .default) { [unowned self] _ in
            self.sendMovieFileToHost()
        }
        let noAction = UIAlertAction(title: "No", style: .cancel)
        alert.addAction(yesAction)
        alert.addAction(noAction)
        viewController?.present(alert, animated: true)
    }
    
    func sendMovieFileToHost() {
        do {
            let movieData = try Data(contentsOf: fileUrl)
            if let connectedPeer {
                try peerSession.send(movieData,
                                     toPeers: [connectedPeer],
                                     with: .reliable)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func sendVideoStreamImage(using data: Data) {
        do {
            if let connectedPeer {
                try peerSession.send(data,
                                     toPeers: [connectedPeer],
                                     with: .unreliable)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
}

extension StreamerVM: MCSessionDelegate {
    func session(_ session: MCSession,
                 peer peerID: MCPeerID,
                 didChange state: MCSessionState) {
        connectedPeer = session.connectedPeers.first
    }
    
    func session(_ session: MCSession,
                 didReceive data: Data,
                 fromPeer peerID: MCPeerID) {
        if let dataString = String(data: data, encoding: .utf8),
           let recordState = RecordingState(rawValue: dataString) {
            changeRecordingState(recordState)
        }
    }
    
    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) {
        
    }
    
    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) {
        
    }
    
}

extension StreamerVM: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, peerSession)
    }
    
}
