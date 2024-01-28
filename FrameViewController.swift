//
//  FrameView.swift
//  HapticCamera
//
//  Created by Jerry on 2023/12/30.
//

import SwiftUI
import UIKit
import AVFoundation
import Vision

protocol BoxCenterDelegate {
    func setBoxCenter(midX: CGFloat?, midY: CGFloat?)
}

class FrameViewController: UIViewController {
    
    private var faceDetectBoxes: [CAShapeLayer] = []
    private var permissionGranted = true
    private let videoOutput = AVCaptureVideoDataOutput()
    private let captureSession = AVCaptureSession()
    
    // Run capture session on a background thread
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenDimensions: CGRect! = nil
    
    var delegate: BoxCenterDelegate?
    
    override func viewDidLoad() {
        self.checkPermission()
        
        sessionQueue.async { [unowned self] in
            guard permissionGranted else { return }
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        screenDimensions = UIScreen.main.bounds
        self.previewLayer.frame = CGRect(x: 0, y: 0, width: screenDimensions.size.width, height: screenDimensions.size.height)

        switch UIDevice.current.orientation {
            // Home button on top
            case UIDeviceOrientation.portraitUpsideDown:
                self.previewLayer.connection?.videoOrientation = .portraitUpsideDown
             
            // Home button on right
            case UIDeviceOrientation.landscapeLeft:
                self.previewLayer.connection?.videoOrientation = .landscapeRight
            
            // Home button on left
            case UIDeviceOrientation.landscapeRight:
                self.previewLayer.connection?.videoOrientation = .landscapeLeft
             
            // Home button at bottom
            case UIDeviceOrientation.portrait:
                self.previewLayer.connection?.videoOrientation = .portrait
                
            default:
                break
        }
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: // The user has previously granted access to the camera.
                self.permissionGranted = true
                
            case .notDetermined: // The user has not yet been asked for camera access.
                self.requestPermission()
                    
            // Combine the two other cases into the default case
            default:
                self.permissionGranted = false
        }
    }
    
    func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    func setupCaptureSession() {
        // Camera input
        guard let videoDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) else { return }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
                         
        // Preview layer
        screenDimensions = UIScreen.main.bounds
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = CGRect(x: 0, y: 0, width: screenDimensions.size.width, height: screenDimensions.size.height)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill // Fill screen
        previewLayer.connection?.videoOrientation = .portrait
        
        // Video output settings
        videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString): NSNumber(value: kCVPixelFormatType_32BGRA)] as [String: Any]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        // Get camera frames and process them in the background thread
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
        captureSession.addOutput(videoOutput)
        videoOutput.connection(with: .video)?.videoOrientation = .portrait
        
        // Updates to UI must be on main queue
        DispatchQueue.main.async { [weak self] in
            self!.view.layer.addSublayer(self!.previewLayer)
        }
    }
    
    func detectFace(image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                  var results = faceDetectionRequest.results else {
                    return
            }
            
            DispatchQueue.main.async {
                if results.count > 0 {
                    self.drawFaceDetectBoxes(observedFaces: results)
                } else {
                    self.clearBoxes()
                }
            }
        })
        
        // Perform request on the image
        let imageResultHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageResultHandler.perform([faceDetectionRequest])
    }
    
    func drawFaceDetectBoxes(observedFaces: [VNFaceObservation]) {
        clearBoxes()
        
//        // Draw the boxes
//        let facesBoundingBoxes: [CAShapeLayer] = observedFaces.map({ (observedFace: VNFaceObservation) -> CAShapeLayer in
//            // Get box boundary from VNFaceObservation
//            let faceBoundingBoxOnScreen = previewLayer.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox)
//            let faceBoundingBoxPath = CGPath(rect: faceBoundingBoxOnScreen, transform: nil)
//            let faceBoundingBoxShape = CAShapeLayer()
//            
//            var midX = CGRectGetMidX(faceBoundingBoxOnScreen)
//            var midY = CGRectGetMidY(faceBoundingBoxOnScreen)
//              
//            // Set properties of the box shape
//            faceBoundingBoxShape.path = faceBoundingBoxPath
//            faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
//            faceBoundingBoxShape.strokeColor = UIColor.green.cgColor
//              
//            return faceBoundingBoxShape
//        })
//        
//        // Add boxes to the view layer and the array
//        facesBoundingBoxes.forEach { faceBoundingBox in
//            view.layer.addSublayer(faceBoundingBox)
//            faceDetectBoxes = facesBoundingBoxes
//        }
        
        // Draw the box of the first face detected
        
        // Get box boundary from VNFaceObservation
        guard let faceBoundingBox: VNFaceObservation = observedFaces.first else {
            return
        }
        let faceBoundingBoxOnScreen = previewLayer.layerRectConverted(fromMetadataOutputRect: faceBoundingBox.boundingBox)
        let faceBoundingBoxPath = CGPath(rect: faceBoundingBoxOnScreen, transform: nil)
        let faceBoundingBoxShape = CAShapeLayer()
        
        delegate?.setBoxCenter(midX: CGRectGetMidX(faceBoundingBoxOnScreen), midY: CGRectGetMidY(faceBoundingBoxOnScreen))
          
        // Set properties of the box shape
        faceBoundingBoxShape.path = faceBoundingBoxPath
        faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
        faceBoundingBoxShape.strokeColor = UIColor.green.cgColor
        
        
        // Add boxes to the view layer and the array
        let singleFaceBoundingBoxShape: [CAShapeLayer] = [faceBoundingBoxShape]
//        singleFaceBoundingBoxShape.append(faceBoundingBoxShape)
        view.layer.addSublayer(faceBoundingBoxShape)
        faceDetectBoxes = singleFaceBoundingBoxShape
    }
    
    func clearBoxes() {
        faceDetectBoxes.forEach { box in
            box.removeFromSuperlayer()
        }
    }
    
}

extension FrameViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        detectFace(image: imageBuffer)
    }
}

struct FrameViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var faceDetectBoxPosition: CGPoint?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let frameViewController = FrameViewController()
        frameViewController.delegate = context.coordinator
        return frameViewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        
    }
    
    class Coordinator: NSObject, BoxCenterDelegate {
        var parent: FrameViewControllerRepresentable
        
        init(_ uiViewController: FrameViewControllerRepresentable) {
            parent = uiViewController
        }
        
        func setBoxCenter(midX: CGFloat?, midY: CGFloat?) {
            if midX != nil, midY != nil {
                parent.faceDetectBoxPosition = CGPoint(x: midX!, y: midY!)
            }
        }
    }
}

//struct FrameView: View {
//    var image: CGImage?
//    private let label = Text("frame")
//    
//    var body: some View {
//        if let image = image {
//            Image(image, scale: 1.0, orientation: .up, label: label)
//        } else {
//            Color.black
//        }
//    }
//}
