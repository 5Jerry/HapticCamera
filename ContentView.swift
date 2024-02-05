import SwiftUI
import UIKit
import CoreHaptics

struct ContentView: View {
    private let initialSharpness: Float = 0.3
    
    @State var hapticsIntensity: Float = 0.0
    @State private var engine: CHHapticEngine?
    @State var faceDetectBoxPosition: CGPoint = CGPoint(x: 0, y: 0)
    @State var tappedLocation: CGPoint = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
    @State var tapFaceDistance: CGFloat?
    @State var previewPhoto: UIImage?
    
    @State private var showPhoto = false
    
    // Timer to handle transient haptic playback:
    @State private var transientTimer: DispatchSourceTimer?
    
    var body: some View {
        ZStack{
            FrameViewControllerRepresentable(faceDetectBoxPosition: $faceDetectBoxPosition, tappedLocation: $tappedLocation, tapFaceDistance: $tapFaceDistance, hapticsIntensity: $hapticsIntensity, previewPhoto: $previewPhoto, showPhoto: $showPhoto)
            VStack {
                Text("Tapped location X: \(tappedLocation.x) Y: \(tappedLocation.y)")
                Text("Face location X: \(faceDetectBoxPosition.x) Y: \(faceDetectBoxPosition.y)")
                Text("Tap and face distance: \(tapFaceDistance ?? 99999)")
                Text("HapticsIntensity: \(hapticsIntensity)")
            }
        }
        .popover(isPresented: $showPhoto,
                 content: {
            ZStack(alignment: .topTrailing) {
                if previewPhoto != nil {
                    Image(uiImage: previewPhoto!)
                        .resizable()
                        .scaledToFit()
                }
                
                HStack {
                    Button(action: {
                        
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .frame(width: 40, height: 40)
                    
                    Button(action: {
                        showPhoto = false
                    }) {
                        Image(systemName: "xmark")
                    }
                    .frame(width: 40, height: 40)
                }
                .frame(width: 100, height: 40, alignment: .topTrailing)
            }
            .presentationCompactAdaptation(.fullScreenCover)
        })
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: {
                
            }) {
                Text("Clear tap position")
            }
            .frame(width: 150, height: 20)
            .padding(5)
            .background(.black)
            .cornerRadius(10)
        }
    }
}
