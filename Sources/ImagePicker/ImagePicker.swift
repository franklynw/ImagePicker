//
//  ImagePicker.swift
//
//  Created by Franklyn Weber on 17/02/2021.
//

import SwiftUI


public struct ImagePicker<T>: UIViewControllerRepresentable {
    
    @Binding private var selectedImage: Result<PHImage, ImagePickerError>?
    @Binding private var item: T?
    
    private let sourceType: UIImagePickerController.SourceType
    
    
    public init(item: Binding<T?>, sourceType: UIImagePickerController.SourceType, selectedImage: Binding<Result<PHImage, ImagePickerError>?>) {
        _item = item
        _selectedImage = selectedImage
        self.sourceType = sourceType
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
                let scale = screenSize.height / cameraHeight
                let offset = (screenSize.height - cameraHeight) / 2
                
                let scaleTransform = CGAffineTransform(scaleX: 1, y: scale)
                let translateTransform = CGAffineTransform(translationX: 0, y: offset)
                let transform = scaleTransform.concatenating(translateTransform)
                
                imagePickerController.cameraViewTransform = transform
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
        }
        
        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            guard let selectedImage = info[.originalImage] as? UIImage else {
                self.parent.selectedImage = .failure(.noImage)
                return
            }
            guard picker.sourceType == .camera else {
                // TODO: get image metadata
                self.parent.selectedImage = .success(.init(image: selectedImage, metadata: .init(location: nil, creationDate: nil)))
                self.parent.item = nil
                return
            }
            
            var editingOverlay: EditingOverlayView!
            
            editingOverlay = EditingOverlayView(frame: picker.view.frame, item: parent._item, initialImage: selectedImage, retake: {
                
                UIView.animate(withDuration: 0.3) {
                    editingOverlay.alpha = 0
                } completion: { _ in
                    editingOverlay.removeFromSuperview()
                }
                
            }, done: parent._selectedImage)
            
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
    }
}
