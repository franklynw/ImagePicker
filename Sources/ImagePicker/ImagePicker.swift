//
//  ImagePicker.swift
//
//  Created by Franklyn Weber on 17/02/2021.
//

import SwiftUI


public struct ImagePicker<T: Identifiable>: UIViewControllerRepresentable {
    
    @Binding private var selectedImage: Result<UIImage, ImagePickerError>?
    @Binding private var item: T?
    
    private let sourceType: UIImagePickerController.SourceType
    
    
    public init(item: Binding<T?>, sourceType: UIImagePickerController.SourceType, selectedImage: Binding<Result<UIImage, ImagePickerError>?>) {
        _item = item
        _selectedImage = selectedImage
        self.sourceType = sourceType
    }
        
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let camera = Camera(item: _item, sourceType: sourceType, selectedImage: _selectedImage)
        return camera.picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {

    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(picker: self)
    }
    
    public class Coordinator: NSObject {

        var picker: ImagePicker

        init(picker: ImagePicker) {
            self.picker = picker
        }
    }
}
