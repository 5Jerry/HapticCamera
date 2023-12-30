import SwiftUI
import CoreHaptics

struct ContentView: View {
    private let initialIntensity: Float = 1.0
    private let initialSharpness: Float = 0.3
    
    @State private var engine: CHHapticEngine?
    @State private var hapticSwitch: Bool = false
    @State private var hapticsIntensity: Float = 0.3
    @State private var continuousPlayer: CHHapticAdvancedPatternPlayer!
    
    // Timer to handle transient haptic playback:
    @State private var transientTimer: DispatchSourceTimer?
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            
            Slider(value: $hapticsIntensity, in: 0.3...1.0)
            
            Button("Test haptics") {
                // testHaptic()
                // complexSuccess()
                hapticSwitch.toggle()
                transientPalettePressed()
            }
        }
        .onAppear(perform: prepareHaptics)
    }
    
    func testHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
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
    }
    
    func transientPalettePressed() {
        if hapticSwitch {
            // Create a timer to play subsequent transient patterns in succession.
            transientTimer?.cancel()
            transientTimer = DispatchSource.makeTimerSource(queue: .main)
            guard let timer = transientTimer else {
                return
            }
            
            timer.schedule(deadline: .now() + .milliseconds(750), repeating: .milliseconds(600))
            timer.setEventHandler() {
                self.playHapticTransient(time: CHHapticTimeImmediate, intensity: hapticsIntensity, sharpness: initialSharpness)
            }
            
            timer.resume()
        } else {
            transientTimer?.cancel()
            transientTimer = nil
        }
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
    
    // Just a Test function
    func complexSuccess() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        var events = [CHHapticEvent]()
        
        for i in stride(from: 0, to: 1, by: 0.1) {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(i))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(i))
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: i)
            events.append(event)
        }
        
        for i in stride(from: 0, to: 1, by: 0.1) {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(1 - i))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(1 - i))
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 1 + i)
            events.append(event)
        }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play pattern: \(error.localizedDescription)")
        }
    }
}
