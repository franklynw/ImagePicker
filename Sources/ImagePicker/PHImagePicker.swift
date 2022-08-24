//
//  PHImagePicker.swift
//  
//
//  Created by Franklyn on 24/08/2022.
//

import SwiftUI
import PhotosUI


public enum PHImagePickerResult {
    case processing
    case selection([UIImage])
    case cancelled
}

public struct PHImagePicker<T>: UIViewControllerRepresentable {
    
    @Binding private var selectedImages: PHImagePickerResult?
    @Binding private var active: T?
    
    private var targetSize: CGSize = UIScreen.main.bounds.size
    
    
    public init(_ active: Binding<T?>, selectedImages: Binding<PHImagePickerResult?>) {
        _active = active
        _selectedImages = selectedImages
    }
    
    public func makeUIViewController(context: Context) -> PHPickerViewController {
        return context.coordinator.imagePickerController
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {

    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    public class Coordinator: PHPickerViewControllerDelegate {
        
        let imagePickerController: PHPickerViewController = {
            var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
            configuration.filter = .images
            configuration.selectionLimit = 5
            return PHPickerViewController(configuration: configuration)
        }()
        
        private let parent: PHImagePicker
        

        init(parent: PHImagePicker) {
            self.parent = parent
            imagePickerController.delegate = self
        }
        
        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            
            let assetIdentifiers = results.compactMap { $0.assetIdentifier }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
            let count = assets.count
            
            guard count > 0 else {
                parent.selectedImages = .cancelled
                parent.active = nil
                return
            }
            
            parent.selectedImages = .processing
            
            let group = DispatchGroup()
            var images = [UIImage]()
            
            (0..<count).forEach { index in
                
                let asset = assets.object(at: index)
                
                group.enter()
                
                PHImageManager.default().requestImage(for: asset, targetSize: parent.targetSize, contentMode: .aspectFit, options: nil) { image, _ in
                    if let image = image {
                        images.append(image)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: DispatchQueue.main) {
                self.parent.selectedImages = .selection(images)
                self.parent.active = nil
            }
        }
    }
}


extension PHImagePicker {
    
    func targetImageSize(_ targetSize: CGSize) -> Self {
        var copy = self
        copy.targetSize = targetSize
        return copy
    }
}
