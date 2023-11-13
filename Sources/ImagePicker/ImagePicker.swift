//
//  ImagePicker.swift
//
//  Created by Franklyn Weber on 17/02/2021.
//

import SwiftUI
import PhotosUI


public struct ImagePicker<T>: UIViewControllerRepresentable {
    
    @Binding private var selectedImage: Result<PHImage, ImagePickerError>?
    @Binding private var item: T?
    
    private var userLocation: CLLocationCoordinate2D?
    private var _savesToPhotoLibrary = false
    
    private let sourceType: UIImagePickerController.SourceType
    private let appeared: (() -> ())?
    
    
    public init(item: Binding<T?>, sourceType: UIImagePickerController.SourceType, appeared: (() -> ())?, selectedImage: Binding<Result<PHImage, ImagePickerError>?>) {
        _item = item
        _selectedImage = selectedImage
        self.sourceType = sourceType
        self.appeared = appeared
    }
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        return context.coordinator.imagePickerController
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {

    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        let imagePickerController = UIImagePickerController()
        
        private let parent: ImagePicker
        

        init(parent: ImagePicker) {
            
            self.parent = parent
            
            super.init()
            
            imagePickerController.sourceType = parent.sourceType
            imagePickerController.delegate = self
            
            if parent.sourceType == .camera {
                
                let screenSize = UIScreen.main.bounds.size
                let cameraAspectRatio = CGFloat(4) / 3
                let cameraHeight = screenSize.width * cameraAspectRatio
                let offset = (screenSize.height - cameraHeight) / 2
                
                let translateTransform = CGAffineTransform(translationX: 0, y: offset)
                
                imagePickerController.cameraViewTransform = translateTransform
                imagePickerController.cameraOverlayView = CameraOverlayView(frame: imagePickerController.view.frame,
                                                                            item: parent._item,
                                                                            cycleFlash: { [weak self] in
                                                                                self?.imagePickerController.cameraFlashMode.cycle()
                                                                                return self?.imagePickerController.cameraFlashMode ?? .off
                                                                            }, capture: {
                                                                                self.imagePickerController.takePicture()
                                                                            }, done: parent._selectedImage
                )
                imagePickerController.cameraFlashMode = .off
                imagePickerController.showsCameraControls = false
            }
            
            parent.appeared?()
        }
        
        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            guard let selectedImage = info[.originalImage] as? UIImage else {
                self.parent.selectedImage = .failure(.noImage)
                return
            }
            guard picker.sourceType == .camera else {
                // this will never happen as we're using PHPickerViewController for non-camera functionality
                self.parent.selectedImage = .success(.init(image: selectedImage, metadata: .init(location: nil, creationDate: nil)))
                self.parent.item = nil
                return
            }
            
            let screenSize = UIScreen.main.bounds.size
            let scale = screenSize.width / selectedImage.size.width
            let correctedImage = selectedImage.withCorrectedRotation(desiredAspect: .portrait)
            let scaledImage = correctedImage.scaled(to: scale) // an image which is the same width as the screen; we pass the original when any edits are committed
            
            var editingOverlay: EditingOverlayView!
            
            editingOverlay = EditingOverlayView(frame: picker.view.frame, item: parent._item, screenImage: scaledImage, originalImage: correctedImage, retake: {
                
                UIView.animate(withDuration: 0.3) {
                    editingOverlay.alpha = 0
                } completion: { _ in
                    editingOverlay.removeFromSuperview()
                }
                
            }, done: imageFinishedEditing)
            
            editingOverlay.alpha = 0
            
            picker.cameraOverlayView?.addSubview(editingOverlay)
            
            UIView.animate(withDuration: 0.3) {
                editingOverlay.alpha = 1
            }
        }
        
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.parent.selectedImage = .failure(.cancelled)
            self.parent.item = nil
        }
        
        private func imageFinishedEditing(_ result: Result<PHImage, ImagePickerError>) {
            switch result {
            case .success(let phImage):
                if parent._savesToPhotoLibrary {
                    saveImageWithMetadata(phImage.image)
                }
                let updatedImage = PHImage(image: phImage.image, metadata: .init(location: parent.userLocation, creationDate: Date()))
                parent.selectedImage = .success(updatedImage)
            case .failure:
                parent.selectedImage = result
            }
        }
        
        private func saveImageWithMetadata(_ image: UIImage) {
            
            let location: CLLocation?
            if let userLocation = parent.userLocation {
                location = .init(latitude: userLocation.latitude, longitude: userLocation.longitude)
            } else {
                location = nil
            }
            
            try? PHPhotoLibrary.shared().performChangesAndWait {
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                request.creationDate = Date()
                request.location = location
            }
        }
    }
}


extension ImagePicker {
    
    public func savesToPhotoLibrary(_ savesToPhotoLibrary: Bool) -> Self {
        var copy = self
        copy._savesToPhotoLibrary = savesToPhotoLibrary
        return copy
    }
    
    public func userLocation(_ userLocation: CLLocationCoordinate2D?) -> Self {
        var copy = self
        copy.userLocation = userLocation
        return copy
    }
}
