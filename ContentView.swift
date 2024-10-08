import SwiftUI
import UIKit
import CoreHaptics
import Photos

struct ContentView: View {
    @State var tappedLocation: CGPoint?
    @State var previewPhoto: UIImage = UIImage()
    @State var showPhoto = false
    @State var showPreviewImage = false
    
    var body: some View {
        ZStack{
            FrameViewControllerRepresentable(tappedLocation: $tappedLocation, previewPhoto: $previewPhoto, showPhoto: $showPhoto)
                .popover(isPresented: $showPhoto,
                         attachmentAnchor: .point(.center),
                         content: {
                    ZStack(alignment: .topTrailing) {
                        Button(action: {
                            showPreviewImage = true
                        }) {
                            Text("Show preview image")
                        }
                        
                        if showPreviewImage {
                            Image(uiImage: previewPhoto)
                                .resizable()
                                .scaledToFit()
                            
                            HStack {
                                Button(action: {
                                    savePhoto()
                                    tappedLocation = nil
                                    showPhoto = false
                                    showPreviewImage = false
                                }) {
                                    Image(systemName: "square.and.arrow.down")
                                }
                                .frame(width: 40, height: 40)
                                .background(.white)
                                .cornerRadius(7)
                                .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
                                
                                Button(action: {
                                    tappedLocation = nil
                                    showPhoto = false
                                    showPreviewImage = false
                                }) {
                                    Image(systemName: "xmark")
                                }
                                .frame(width: 40, height: 40)
                                .background(.white)
                                .cornerRadius(7)
                                .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
                            }
                            .frame(width: 100, height: 50, alignment: .topTrailing)
                        }
                    }
                    .interactiveDismissDisabled()
                })
            if tappedLocation == nil {
                VStack(alignment: .center) {
                    Text("Rotate device first for photo orientation\n Then tap the screen to indicate\n the desired face location")
                        .background(.black)
                        .foregroundStyle(.white)
                        .font(.headline)
                        .opacity(1.0)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
                .background(.white)
                .opacity(0.7)
                .onTapGesture { location in
                    tappedLocation = location
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: {
                tappedLocation = nil
            }) {
                Text("Clear tap position")
            }
            .frame(width: 150, height: 20)
            .padding(5)
            .background(.black)
            .cornerRadius(10)
        }
    }
    
    func savePhoto() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { (status) in
            if status == .authorized {
                do {
                    try PHPhotoLibrary.shared().performChangesAndWait {
                        PHAssetChangeRequest.creationRequestForAsset(from: self.previewPhoto)
                        print("photo has saved in library...")
                    }
                } catch let error {
                    print("failed to save photo in library: ", error)
                }
            } else {
                print("Something went wrong with permission...")
            }
        }
    }
}
