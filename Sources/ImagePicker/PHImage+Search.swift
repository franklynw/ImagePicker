//
//  File.swift
//  
//
//  Created by Franklyn on 24/10/2023.
//

import Foundation
import PhotosUI


extension PHImage {
    
    public static func search(from fromDate: Date, to toDate: Date, completion: @escaping (Result<[PHImage], PHImageError>) -> ()) {
        
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .denied, .restricted, .notDetermined:
                    completion(.failure(.libraryAccessDenied))
                case .authorized, .limited:
                    doSearch(from: fromDate, to: toDate, completion: completion)
                @unknown default:
                    fatalError()
                }
            }
        }
    }
    
    private static func doSearch(from fromDate: Date, to toDate: Date, targetImageSize: CGSize = UIScreen.main.bounds.size, completion: @escaping (Result<[PHImage], PHImageError>) -> ()) {
        
        let fetchOptions = PHFetchOptions()
        
        let fromPredicate = NSPredicate(format: "%K >= %@", "creationDate", fromDate as CVarArg)
        let toPredicate = NSPredicate(format: "%K <= %@", "creationDate", toDate as CVarArg)
        fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fromPredicate, toPredicate])
        
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            PHFetchResultProcessor.process(assets, targetSize: targetImageSize) { result in
                
                switch result {
                case .processing:
                    break
                case .selection(let images), .partialSuccess(let images, _):
                    DispatchQueue.main.async {
                        completion(.success(images))
                    }
                case .cancelled:
                    completion(.failure(.cancelled))
                }
            }
        }
    }
}
