//
//  PHFetchResultProcessor.swift
//  
//
//  Created by Franklyn on 14/09/2022.
//

import Foundation
import PhotosUI
import CoreLocation


public class PHFetchResultProcessor {
    
    fileprivate struct ImageInfo {
        let image: PHImage
        let id: Int
        let degraded: Bool
    }
    
    public static func process(_ assets: PHFetchResult<PHAsset>, targetSize: CGSize, result: @escaping (PHImagePickerResult) -> ()) {
        
        let count = assets.count
        
        guard count > 0 else {
            result(.cancelled)
            return
        }
        
        result(.processing)
        
        var imageResults = [ImageInfo]()
        var importError: String?
        
        (0..<count).forEach { index in
            
            let asset = assets.object(at: index)
            
            let options = PHImageRequestOptions()
            options.isSynchronous = true
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, info in
                if let info = info, let id = info[PHImageResultRequestIDKey] as? Int {
                    if let image = image {
                        let degraded = info[PHImageResultIsDegradedKey] as? Int == 1
                        let phImage = PHImage(image: image, metadata: .init(location: asset.location?.coordinate, creationDate: asset.creationDate))
                        imageResults.append(.init(image: phImage, id: id, degraded: degraded))
                    } else {
                        importError = info[PHImageErrorKey] as? String ?? "Unknown error"
                    }
                }
            }
        }
        
        let highQualityResults = imageResults.reduce(into: [ImageInfo]()) { result, imageResult in
            if !result.contains(where: { $0.id == imageResult.id }) {
                if imageResult.degraded {
                    if let hqVersion = imageResults.first(where: { $0.id == imageResult.id && !$0.degraded }) {
                        result.append(hqVersion)
                    } else {
                        result.append(imageResult)
                    }
                } else {
                    result.append(imageResult)
                }
            }
        }
        
        if let importError = importError {
            result(.partialSuccess(highQualityResults.map { $0.image }, error: importError))
        } else {
            result(.selection(highQualityResults.map { $0.image }))
        }
    }
}
