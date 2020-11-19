//
//  ViewController.swift
//  LiveObjectDetection
//
//  Created by Auriga Aristo on 04/11/20.
//

import UIKit
import Vision

class ViewController: UIViewController {
    
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var boxPreview: BoundingBoxView!
    
    private let objectDetectionModel = try! YOLOv3Tiny(configuration: .init())
    
    // MARK: - Vision Properties
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    
    // MARK: - AV Property
    var videoHandler: VideoHandler!
    let semaphore = DispatchSemaphore(value: 1)
    
    // MARK: - TableView Data
    var predictions: [VNRecognizedObjectObservation] = []
    
    //MARK: - View Controller Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupModel()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        videoHandler.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        videoHandler.stop()
    }
    
    func setupModel(){
        if let model = try? VNCoreMLModel(for: objectDetectionModel.model) {
            self.visionModel = model
            request = VNCoreMLRequest(model: model, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError("fail to create vision model")
        }
    }
    
    func setupCamera(){
        videoHandler = VideoHandler()
        videoHandler.delegate = self
        videoHandler.fps = 30
        videoHandler.setUp(sessionPreset: .high) { success in
            
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoHandler.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // start video preview when setup is done
                self.videoHandler.start()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoHandler.previewLayer?.frame = videoPreview.bounds
    }
}

//MARK: - Video Handler Delegate
extension ViewController: VideoHandlerDelegate {
    func videoCapture(_ capture: VideoHandler, didCaptureVideoFrame: CVPixelBuffer?, timestamp: CMTime) {
        if let pixelBuffer = didCaptureVideoFrame {
            predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
}

//MARK: - ML Post Processing
extension ViewController {
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }

        semaphore.wait()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {

        if let predictions = request.results as? [VNRecognizedObjectObservation] {
            
            self.predictions = predictions
            DispatchQueue.main.async {
                self.boxPreview.predictedObjects = predictions
            }
        }
        semaphore.signal()
    }
}
