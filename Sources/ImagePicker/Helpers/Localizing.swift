//
//  Localizing.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import Foundation


protocol Localizing {
    var localizedKey: String { get }
}

extension Localizing {
    
    var localized: String {
        return NSLocalizedString(localizedKey, bundle: .module, comment: localizedKey)
    }
}
