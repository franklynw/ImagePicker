//
//  UIImagePickerController+Extensions.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import UIKit


extension UIImagePickerController.CameraFlashMode {
    
    mutating func cycle() {
        switch self {
        case .auto: self = .on
        case .on: self = .off
        case .off: self = .auto
        @unknown default: break
        }
    }
    
    var systemImage: String {
        switch self {
        case .auto: return "bolt.badge.a.fill"
        case .on: return "bolt.circle.fill"
        case .off: return "bolt.slash.circle.fill"
        @unknown default: return "bolt.badge.a.fill"
        }
    }
}
