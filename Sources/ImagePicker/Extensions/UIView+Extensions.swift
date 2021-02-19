//
//  UIView+Extensions.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import UIKit


extension UIView {
    
    func pinEdgesToSuperView() {
        
        translatesAutoresizingMaskIntoConstraints = false
        
        guard let superview = superview else {
            return
        }
        
        leadingAnchor.constraint(equalTo: superview.leadingAnchor).isActive = true
        topAnchor.constraint(equalTo: superview.topAnchor).isActive = true
        trailingAnchor.constraint(equalTo: superview.trailingAnchor).isActive = true
        bottomAnchor.constraint(equalTo: superview.bottomAnchor).isActive = true
    }
}
