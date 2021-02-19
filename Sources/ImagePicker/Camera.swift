//
//  Camera.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import SwiftUI


class Camera<T: Identifiable>: NSObject {

    @Binding private var selectedImage: Result<UIImage, ImagePickerError>?
    @Binding private var item: T?
    
    let picker: UIImagePickerController
    
    
    init(item: Binding<T?>, sourceType: UIImagePickerController.SourceType, selectedImage: Binding<Result<UIImage, ImagePickerError>?>) {
        
        picker = UIImagePickerController()
        
        _item = item
        _selectedImage = selectedImage
        
        super.init()
        
        picker.sourceType = sourceType
        
        if sourceType == .camera {
            
            let screenSize = UIScreen.main.bounds.size
            let cameraAspectRatio = CGFloat(4) / 3
            let cameraHeight = screenSize.width * cameraAspectRatio
            let scale = screenSize.height / cameraHeight
            let offset = (screenSize.height - cameraHeight) / 2
            
            let scaleTransform = CGAffineTransform(scaleX: 1, y: scale)
            let translateTransform = CGAffineTransform(translationX: 0, y: offset)
            let transform = scaleTransform.concatenating(translateTransform)
            
            picker.cameraViewTransform = transform
            picker.cameraOverlayView = CameraOverlayView(frame: picker.view.frame,
                                                         item: item,
                                                         cycleFlash: { [weak self] in
                                                            self?.picker.cameraFlashMode.cycle()
                                                            return self?.picker.cameraFlashMode ?? .off
                                                         }, capture: {
                                                            self.picker.takePicture()
                                                         }, done: _selectedImage
            )
            picker.cameraFlashMode = .off
            picker.showsCameraControls = false
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func editImage(_ image: UIImage) {
        
        var editingOverlay: EditingOverlayView<T>!
        
        editingOverlay = EditingOverlayView(frame: picker.view.frame, item: _item, initialImage: image, retake: {
            
            UIView.animate(withDuration: 0.3) {
                editingOverlay.alpha = 0
            } completion: { _ in
                editingOverlay.removeFromSuperview()
            }
            
        }, done: _selectedImage)
        
        editingOverlay.alpha = 0
        
        picker.cameraOverlayView?.addSubview(editingOverlay)
        
        UIView.animate(withDuration: 0.3) {
            editingOverlay.alpha = 1
        }
    }
}
