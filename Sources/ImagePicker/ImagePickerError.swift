//
//  ImagePickerError.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import Foundation


public enum ImagePickerError: String, Error, Localizing, LocalizedError {
    case noSelf
    case cancelled
    case noImage
    
    var localizedKey: String {
        return "ImagePickerError_" + rawValue
    }
    
    public var errorDescription: String? {
        switch self {
        case .noSelf, .noImage:
            return localized
        case .cancelled:
            return nil
        }
    }
}
