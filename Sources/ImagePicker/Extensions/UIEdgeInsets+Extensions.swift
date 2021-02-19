//
//  UIEdgeInsets+Extensions.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import UIKit


extension UIEdgeInsets {
    
    var topLeft: CGPoint {
        get {
            return CGPoint(x: left, y: top)
        }
        set {
            self.left = newValue.x
            self.top = newValue.y
        }
    }
    
    var bottomRight: CGPoint {
        get {
            return CGPoint(x: right, y: bottom)
        }
        set {
            self.right = newValue.x
            self.bottom = newValue.y
        }
    }
    
    func bottomRight(in rect: CGRect) -> CGPoint {
        return CGPoint(x: rect.width - right, y: rect.height - bottom)
    }
}
