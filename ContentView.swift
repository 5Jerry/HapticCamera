import SwiftUI

struct ContentView: View {
    
//    @StateObject private var model = FrameHandler()
//        
//    var body: some View {
//        FrameView(image: model.frame)
//            .ignoresSafeArea()
//    }
    
    @State var faceDetectBoxPosition: CGPoint?
    
    var body: some View {
        FrameViewControllerRepresentable(faceDetectBoxPosition: $faceDetectBoxPosition)
            .ignoresSafeArea()
            .onTapGesture { location in
                print("1234 Tapped at \(location)")
                print("1234 face box center position \(String(describing: faceDetectBoxPosition))")
            }
    }
}
