//
//  File.swift
//  
//
//  Created by Franklyn on 24/10/2023.
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
            if let latitude = try container.decodeIfPresent(Double.self, forKey: .latitude),
               let longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) {
                location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            } else {
                location = nil
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encodeIfPresent(creationDate, forKey: .creationDate)
            try container.encodeIfPresent(location?.latitude, forKey: .latitude)
            try container.encodeIfPresent(location?.longitude, forKey: .longitude)
        }
    }
    
    public enum PHImageError: Error {
        case libraryAccessDenied
        case cancelled
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
