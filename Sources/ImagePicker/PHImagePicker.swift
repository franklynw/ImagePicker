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
    
    private var selectionLimit = 5
    private var targetSize: CGSize = UIScreen.main.bounds.size
    private var authorizationResponse: ((PHAuthorizationStatus) -> ())?
    
    
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
        
        let imagePickerController: PHPickerViewController
        
        private let parent: PHImagePicker
        

        init(parent: PHImagePicker) {
            
            let authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if authorizationStatus == .notDetermined {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    
                    parent.authorizationResponse?(status)
                    
                    if !(status == .authorized || status == .limited) {
                        parent.active = nil
                    }
                }
            } else {
                parent.authorizationResponse?(authorizationStatus)
                
                if !(authorizationStatus == .authorized || authorizationStatus == .limited) {
                    parent.active = nil
                }
            }
            
            self.parent = parent
            
            var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
            configuration.filter = .images
            configuration.selectionLimit = parent.selectionLimit
            
            imagePickerController = PHPickerViewController(configuration: configuration)
            
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
                
                PHImageManager.default().requestImage(for: asset, targetSize: parent.targetSize, contentMode: .aspectFit, options: nil) { image, info in
                    if info?[PHImageResultIsDegradedKey] as? Int == 0, let image = image {
                        images.append(image)
                        group.leave()
                    }
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
    
    public func selectionLimit(_ selectionLimit: Int) -> Self {
        var copy = self
        copy.selectionLimit = selectionLimit
        return copy
    }
    
    public func targetImageSize(_ targetSize: CGSize) -> Self {
        var copy = self
        copy.targetSize = targetSize
        return copy
    }
    
    public func authorizationResponse(_ authorizationResponse: @escaping (PHAuthorizationStatus) -> ()) -> Self {
        var copy = self
        copy.authorizationResponse = authorizationResponse
        return copy
    }
}


extension PHAuthorizationStatus {
    
    public var canAccessPhotos: Bool {
        switch self {
        case .notDetermined, .restricted, .denied:
            return false
        case .authorized, .limited:
            return true
        @unknown default:
            return false
        }
    }
}
