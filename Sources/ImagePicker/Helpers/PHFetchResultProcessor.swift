//
//  PHFetchResultProcessor.swift
//  
//
//  Created by Franklyn on 14/09/2022.
//

import Foundation
import PhotosUI
import CoreLocation


public struct PHImage: Equatable, Codable {
    public let image: UIImage
    public let metadata: Metadata
    
    public struct Metadata: Equatable, Codable {
        public let location: CLLocationCoordinate2D?
        public let creationDate: Date?
        
        public var data: Data? {
            try? JSONEncoder().encode(self)
        }
        
        public init(location: CLLocationCoordinate2D?, creationDate: Date?) {
            self.location = location
            self.creationDate = creationDate
        }
        
        public static let empty: Metadata = .init(location: nil, creationDate: nil)
        
        public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
            return lhs.location?.latitude == rhs.location?.latitude && lhs.location?.longitude == rhs.location?.longitude && lhs.creationDate == rhs.creationDate
        }
        
        private enum CodingKeys: String, CodingKey {
            case creationDate
            case latitude
            case longitude
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate)
            let latitude = try container.decode(Double.self, forKey: .latitude)
            let longitude = try container.decode(Double.self, forKey: .longitude)
            location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encodeIfPresent(creationDate, forKey: .creationDate)
            try container.encodeIfPresent(location?.latitude, forKey: .latitude)
            try container.encodeIfPresent(location?.longitude, forKey: .longitude)
        }
    }
    
    public init(image: UIImage, metadata: Metadata) {
        self.image = image
        self.metadata = metadata
    }
    
    private enum CodingKeys: String, CodingKey {
        case imageData
        case metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let imageData = try container.decode(Data.self, forKey: .imageData)
        guard let image = UIImage(data: imageData) else {
            throw DecodingError.typeMismatch(UIImage.self, .init(codingPath: [CodingKeys.imageData], debugDescription: "The data could not be decoded into a UIImage"))
        }
        self.image = image
        metadata = try container.decode(Metadata.self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(image.pngData(), forKey: .imageData)
        try container.encode(metadata, forKey: .metadata)
    }
    
    public static let empty: PHImage = .init(image: UIImage(), metadata: .init(location: nil, creationDate: nil))
}

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
