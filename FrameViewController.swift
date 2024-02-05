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
import CoreHaptics

protocol BoxCenterDelegate {
    func setBoxCenter(continuousPlayer: CHHapticAdvancedPatternPlayer?, midX: CGFloat?, midY: CGFloat?)
    func getPhoto(photo: AVCapturePhoto)
}

class FrameViewController: UIViewController {
    
    private var faceDetectBoxes: [CAShapeLayer] = []
    private var permissionGranted = true
    private var captureDevice: AVCaptureDevice?
    private var deviceInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private var photoOutput = AVCapturePhotoOutput()
    private let captureSession = AVCaptureSession()
    
    // Run capture session on a background thread
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenDimensions: CGRect! = nil
    
    var delegate: BoxCenterDelegate?
    
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    
    var takePhotoFlag = 0
    
    private var deviceOrientation: UIDeviceOrientation {
        var orientation = UIDevice.current.orientation
        if orientation == UIDeviceOrientation.unknown {
            orientation = UIScreen.main.orientation
        }
        return orientation
    }
    
    override func viewDidLoad() {
        self.createContinuousHapticPlayer()
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
    
    func createContinuousHapticPlayer() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Engine Error: \(error.localizedDescription)")
        }
        
        // Create an intensity parameter:
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: 0.5)
        
        // Create a sharpness parameter:
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: 0.5)
        
        // Create a continuous event with a long duration from the parameters.
        let continuousEvent = CHHapticEvent(eventType: .hapticContinuous,
                                            parameters: [intensity, sharpness],
                                            relativeTime: 0,
                                            duration: 100)
        
        do {
            // Create a pattern from the continuous haptic event.
            let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])
            
            // Create a player from the continuous haptic pattern.
            continuousPlayer = try engine?.makeAdvancedPlayer(with: pattern)
            
        } catch let error {
            print("Pattern Player Creation Error: \(error)")
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
//        guard let videoDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) else { return }
        guard let videoDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        captureDevice = videoDevice
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        deviceInput = videoDeviceInput
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
        
        // Setup photo output
        captureSession.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
    }
    
    func detectFace(image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                  let results = faceDetectionRequest.results else {
                    return
            }
            
            DispatchQueue.main.async {
                if results.count > 0 {
                    self.drawFaceDetectBoxes(observedFaces: results)
                } else {
                    self.clearBoxes()
                    self.delegate?.setBoxCenter(continuousPlayer: self.continuousPlayer, midX: nil, midY: nil)
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
        
        delegate?.setBoxCenter(continuousPlayer: continuousPlayer, midX: CGRectGetMidX(faceBoundingBoxOnScreen), midY: CGRectGetMidY(faceBoundingBoxOnScreen))
          
        // Set properties of the box shape
        faceBoundingBoxShape.path = faceBoundingBoxPath
        faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
        faceBoundingBoxShape.strokeColor = UIColor.green.cgColor
        
        if takePhotoFlag == 0 {
            takePhoto()
        }
        takePhotoFlag = 1
        
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
    
    func takePhoto() {
        sessionQueue.async {
        
            var photoSettings = AVCapturePhotoSettings()

            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            let isFlashAvailable = self.deviceInput?.device.isFlashAvailable ?? false
            photoSettings.flashMode = isFlashAvailable ? .auto : .off
//            photoSettings.isHighResolutionPhotoEnabled = true
            
            if let maxPhotoDimensions = self.captureDevice?.activeFormat.formatDescription {
                photoSettings.maxPhotoDimensions = CMVideoFormatDescriptionGetDimensions(maxPhotoDimensions)
                print("5555 maxPhotoDimensions width: \(CMVideoFormatDescriptionGetDimensions(maxPhotoDimensions).width) maxPhotoDimensions height: \(CMVideoFormatDescriptionGetDimensions(maxPhotoDimensions).height)")
            }
            
//            if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
//                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
//            }
            
            if photoSettings.availablePreviewPhotoPixelFormatTypes.count > 0 {
                photoSettings.previewPhotoFormat = [
                    kCVPixelBufferPixelFormatTypeKey : photoSettings.availablePreviewPhotoPixelFormatTypes.first!,
                    kCVPixelBufferWidthKey : 1920,
                    kCVPixelBufferHeightKey : 1080
                ] as [String: Any]
            }
            
            photoSettings.photoQualityPrioritization = .quality
            
            if let photoOutputVideoConnection = self.photoOutput.connection(with: .video) {
                if photoOutputVideoConnection.isVideoOrientationSupported,
                    let videoOrientation = self.videoOrientationFor(self.deviceOrientation) {
                    photoOutputVideoConnection.videoOrientation = videoOrientation
                }
            }
            
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    private func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait: return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown: return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft: return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight: return AVCaptureVideoOrientation.landscapeLeft
        default: return nil
        }
    }
    
    
    
}

extension FrameViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        detectFace(image: imageBuffer)
    }
}

extension FrameViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        delegate?.getPhoto(photo: photo)
    }
}

struct FrameViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var faceDetectBoxPosition: CGPoint
    @Binding var tappedLocation: CGPoint
    @Binding var tapFaceDistance: CGFloat?
    @Binding var hapticsIntensity: Float
    @Binding var previewPhoto: UIImage?
    @Binding var showPhoto: Bool
    
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
        
        func setBoxCenter(continuousPlayer: CHHapticAdvancedPatternPlayer?, midX: CGFloat?, midY: CGFloat?) {
            if midX != nil, midY != nil {
                parent.faceDetectBoxPosition = CGPoint(x: midX!, y: midY!)
                
                // Calculate distance between tapped location and face center
                parent.tapFaceDistance = sqrt(pow(parent.tappedLocation.x - midX!, 2) + pow(parent.tappedLocation.y - midY!, 2))
                if parent.tapFaceDistance != nil {
                    parent.hapticsIntensity = Float(1 - parent.tapFaceDistance! / 800)
                }
                
                // Create dynamic parameters for the updated intensity & sharpness.
                let intensityParameter = CHHapticDynamicParameter(parameterID: .hapticIntensityControl,
                                                                  value: parent.hapticsIntensity,
                                                                  relativeTime: 0)
        
                let sharpnessParameter = CHHapticDynamicParameter(parameterID: .hapticSharpnessControl,
                                                                  value: 0.5,
                                                                  relativeTime: 0)
        
                // Send dynamic parameters to the haptic player.
                do {
                    try continuousPlayer?.sendParameters([intensityParameter, sharpnessParameter],
                                                        atTime: CHHapticTimeImmediate)
                } catch let error {
                    print("Dynamic Parameter Error: \(error)")
                }
                
                do {
                    // Begin playing continuous pattern.
                    try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
                } catch let error {
                    print("Error starting the continuous haptic player: \(error)")
                }
            } else {
                // Stop playing the haptic pattern.
                do {
                    try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
                } catch let error {
                    print("Error stopping the continuous haptic player: \(error)")
                }
            }
        }
        
        func getPhoto(photo: AVCapturePhoto) {
            guard let imageData = photo.fileDataRepresentation() else { return }
            guard let uiImage = UIImage(data: imageData) else { return }
            parent.previewPhoto = uiImage
            parent.showPhoto = true
        }
    }
}

fileprivate extension UIScreen {

    var orientation: UIDeviceOrientation {
        let point = coordinateSpace.convert(CGPoint.zero, to: fixedCoordinateSpace)
        if point == CGPoint.zero {
            return .portrait
        } else if point.x != 0 && point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0 && point.y != 0 {
            return .landscapeRight //.landscapeLeft
        } else if point.x != 0 && point.y == 0 {
            return .landscapeLeft //.landscapeRight
        } else {
            return .unknown
        }
    }
}

fileprivate extension Image.Orientation {

    init(_ cgImageOrientation: CGImagePropertyOrientation) {
        switch cgImageOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
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
