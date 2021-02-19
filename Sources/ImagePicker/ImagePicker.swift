//
//  ImagePicker.swift
//
//  Created by Franklyn Weber on 17/02/2021.
//

import SwiftUI


public struct ImagePicker<T: Identifiable>: UIViewControllerRepresentable {
    
    @Binding private var selectedImage: Result<UIImage, ImagePickerError>?
    @Binding private var item: T?
    
    private let camera: Camera<T>
    
    
    public init(item: Binding<T?>, sourceType: UIImagePickerController.SourceType, selectedImage: Binding<Result<UIImage, ImagePickerError>?>) {
        _item = item
        _selectedImage = selectedImage
        camera = Camera(item: _item, sourceType: sourceType, selectedImage: _selectedImage)
    }
        
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = camera.picker
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {

    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(picker: self)
    }
    
    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        private let picker: ImagePicker

        init(picker: ImagePicker) {
            self.picker = picker
        }
        
        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            guard let selectedImage = info[.originalImage] as? UIImage else {
                self.picker.selectedImage = .failure(.noImage)
                return
            }
            guard picker.sourceType == .camera else {
                self.picker.selectedImage = .success(selectedImage)
                self.picker.item = nil
                return
            }
            
            self.picker.camera.editImage(selectedImage)
        }
        
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.picker.selectedImage = .failure(.cancelled)
            self.picker.item = nil
        }
    }
}
