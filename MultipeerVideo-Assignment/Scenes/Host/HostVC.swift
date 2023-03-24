//
//  HostVC.swift
//  MultipeerVideo-Assignment
//
//  Created by cleanmac on 16/01/23.
//

import UIKit
import Combine

final class HostVC: UIViewController {
    
    @IBOutlet private weak var connectButton: UIButton!
    @IBOutlet private weak var connectionStatusLabel: UILabel!
    @IBOutlet private weak var seeVideoButton: UIButton!
    @IBOutlet private weak var previewCameraView: UIView!
    @IBOutlet private weak var recordButton: UIButton!
    
    private var viewModel: HostVM!
    private var disposables = Set<AnyCancellable>()
    
    init() {
        super.init(nibName: "HostVC", bundle: nil)
        viewModel = HostVM(viewController: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Doesn't support Storyboard initializations")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
    }
    
    private func setupBindings() {
        viewModel
            .$connectedPeers
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard !value.isEmpty else {
                    self?.connectionStatusLabel.text = "Not connected"
                    self?.recordButton.isHidden = true
                    return
                }
                
                let peers = String(describing: value.map{ $0.displayName })
                self?.connectionStatusLabel.text = "Connected to: \(peers)"
                self?.recordButton.isHidden = false
            }.store(in: &disposables)
        
        viewModel
            .$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.recordButton.setTitle(value == .isRecording ? "Stop Recording" : "Start Recording", for: .normal)
            }.store(in: &disposables)
    }
    
    @IBAction private func buttonActions(_ sender: UIButton) {
        if sender == connectButton {
            viewModel.showPeerBrowserModal()
        } else if sender == recordButton {
            if viewModel.recordingState != .finishedRecording {
                viewModel.changeRecordingState()
            }
        } else if sender == seeVideoButton {
            viewModel.showVideoResolutionAlert()
        }
    }
    
}
