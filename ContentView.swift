import SwiftUI
import UIKit
import CoreHaptics

struct ContentView: View {
    
//    @StateObject private var model = FrameHandler()
//        
//    var body: some View {
//        FrameView(image: model.frame)
//            .ignoresSafeArea()
//    }
    private let initialSharpness: Float = 0.3
    
    @State var hapticsIntensity: Float = 0.35
    @State private var engine: CHHapticEngine?
    @State var faceDetectBoxPosition: CGPoint = CGPoint(x: 0, y: 0)
    @State var tappedLocation: CGPoint = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
    @State var tapFaceDistance: CGFloat?
    
    // Timer to handle transient haptic playback:
    @State private var transientTimer: DispatchSourceTimer?
    
    var body: some View {
        ZStack{
            FrameViewControllerRepresentable(faceDetectBoxPosition: $faceDetectBoxPosition, tappedLocation: $tappedLocation, tapFaceDistance: $tapFaceDistance, hapticsIntensity: $hapticsIntensity)
                .ignoresSafeArea()
                .onTapGesture { location in
                    tappedLocation = location
                    print("1234 Tapped at \(location)")
                    print("1234 face box center position \(String(describing: faceDetectBoxPosition))")
                }
                .onAppear(perform: prepareHaptics)
            VStack {
                Text("Tapped location X: \(tappedLocation.x) Y: \(tappedLocation.y)")
                Text("Face location X: \(faceDetectBoxPosition.x) Y: \(faceDetectBoxPosition.y)")
                Text("Tap and face distance: \(tapFaceDistance ?? 99999)")
            }
        }
    }
    
    // Initiate haptic engine
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Engine Error: \(error.localizedDescription)")
        }
        
//        if faceDetectBoxPosition != nil {
        
            // Create a timer to play subsequent transient patterns in succession.
            transientTimer?.cancel()
            transientTimer = DispatchSource.makeTimerSource(queue: .main)
            guard let timer = transientTimer else {
                return
            }
            
            timer.schedule(deadline: .now(), repeating: .milliseconds(400))
            timer.setEventHandler() {
                self.playHapticTransient(time: CHHapticTimeImmediate, intensity: hapticsIntensity, sharpness: initialSharpness)
            }
            
            timer.resume()
        
            
//        } else {
//            transientTimer?.cancel()
//            transientTimer = nil
//        }
    }
    
    /// - Tag: PlayTransientPattern
    // Play a haptic transient pattern at the given time, intensity, and sharpness.
    private func playHapticTransient(time: TimeInterval,
                                     intensity: Float,
                                     sharpness: Float) {
        
        
        // Create an event (static) parameter to represent the haptic's intensity.
        let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                        value: intensity)
        
        // Create an event (static) parameter to represent the haptic's sharpness.
        let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                        value: sharpness)
        
        // Create an event to represent the transient haptic pattern.
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensityParameter, sharpnessParameter],
                                  relativeTime: 0)
        
        // Create a pattern from the haptic event.
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            
            // Create a player to play the haptic pattern.
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate) // Play now.
        } catch let error {
            print("Error creating a haptic transient pattern: \(error)")
        }
    }
}
