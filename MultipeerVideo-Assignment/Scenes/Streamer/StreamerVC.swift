//
//  StreamerVC.swift
//  MultipeerVideo-Assignment
//
//  Created by cleanmac on 16/01/23.
//

import UIKit
import Combine
import MultipeerConnectivity
import AVFoundation

final class StreamerVC: UIViewController {
    
    @IBOutlet private weak var connectionStatusLabel: UILabel!
    @IBOutlet private weak var previewLayerView: UIView!
    @IBOutlet private weak var recordStateLabel: UILabel!
    
    private(set) var captureSession: AVCaptureSession!
    private(set) var previewLayer: AVCaptureVideoPreviewLayer!
    private(set) var movieOutput: AVCaptureMovieFileOutput!
    private(set) var movieFileOutputConnection: AVCaptureConnection?
    private(set) var videoDataOutput: AVCaptureVideoDataOutput!
    
    private var captureQueue = DispatchQueue(label: "capture-queue")
    private var viewModel: StreamerVM!
    private var disposables = Set<AnyCancellable>()
    
    init() {
        super.init(nibName: "StreamerVC", bundle: nil)
        viewModel = StreamerVM(viewController: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Doesn't support Storyboard initializations")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
        setupPreviewLayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    private func setupBindings() {
        viewModel
            .$connectedPeer
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] value in
                guard let value else {
                    self?.connectionStatusLabel.text = "Not connected"
                    return
                }
                
                self?.connectionStatusLabel.text = "Connected to: \(value.displayName)"
            }).store(in: &disposables)
        
        viewModel
            .$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.recordHandler(value)
            }.store(in: &disposables)
        
        viewModel
            .$videoOrientation
            .sink { [weak self] value in
                self?.setVideoOrientation(value)
            }.store(in: &disposables)
    }
    
    private func setupPreviewLayer() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let audioCaptureDevice = AVCaptureDevice.default(for: .audio) else { return }
        let videoInput: AVCaptureDeviceInput
        let audioInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            audioInput = try AVCaptureDeviceInput(device: audioCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput),
           captureSession.canAddInput(audioInput) {
            captureSession.addInput(videoInput)
            captureSession.addInput(audioInput)
        } else {
            return
        }
        
        movieOutput = AVCaptureMovieFileOutput()
        //videoDataOutput = AVCaptureVideoDataOutput()
        
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            movieFileOutputConnection = movieOutput.connection(with: .video)
        } else {
            return
        }
        
        //setupDataOutput()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        DispatchQueue.main.async { [unowned self] in
            self.previewLayer.frame = self.previewLayerView.bounds
            self.previewLayerView.layer.addSublayer(self.previewLayer)
        }
        
        previewLayerView.layer.cornerRadius = 10
    }
    
    private func setupDataOutput() {
        videoDataOutput.videoSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)
        ]
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: captureQueue)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
        }
        
        captureSession.commitConfiguration()
    }
    
    func setVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        movieFileOutputConnection?.videoOrientation = orientation
    }
    
    private func recordHandler(_ state: RecordingState) {
        if state == .isRecording {
            try? FileManager.default.removeItem(at: viewModel.fileUrl)
            movieOutput.startRecording(to: viewModel.fileUrl,
                                       recordingDelegate: self)
            recordStateLabel.text = "Recording..."
        } else if state == .finishedRecording {
            movieOutput.stopRecording()
            recordStateLabel.text = "Recording finished!"
        } else {
            recordStateLabel.text = ""
        }
    }
    
}

extension StreamerVC: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if error == nil {
            viewModel.sendMovieFileToHost()
        }
    }
    
}

extension StreamerVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        if let imageBuffer {
            CVPixelBufferLockBaseAddress(imageBuffer, [])
            let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
            let bytesPerRow: size_t? = CVPixelBufferGetBytesPerRow(imageBuffer)
            let width: size_t? = CVPixelBufferGetWidth(imageBuffer)
            let height: size_t? = CVPixelBufferGetHeight(imageBuffer)
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let newContext = CGContext(data: baseAddress,
                                       width: width ?? 0,
                                       height: height ?? 0,
                                       bitsPerComponent: 8,
                                       bytesPerRow: bytesPerRow ?? 0,
                                       space: colorSpace,
                                       bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
            
            if let newImage = newContext?.makeImage() {
                let image = UIImage(cgImage: newImage,
                                    scale: 1,
                                    orientation: .up)
                
                CVPixelBufferUnlockBaseAddress(imageBuffer, [])
                
                if let data = image.jpegData(compressionQuality: 0.7) {
                    viewModel.sendVideoStreamImage(using: data)
                }
            }
        }
    }
}
