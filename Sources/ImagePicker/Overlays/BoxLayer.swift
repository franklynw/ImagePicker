//
//  BoxLayer.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import UIKit


class BoxLayer: CAShapeLayer {
    
    var topLeft: CGPoint {
        didSet {
            update()
        }
    }
    var bottomRight: CGPoint {
        didSet {
            update()
        }
    }
    
    
    init(frame: CGRect, initialMask: CGRect) {
        
        topLeft = initialMask.origin
        bottomRight = CGPoint(x: initialMask.maxX, y: initialMask.maxY)
        
        super.init()
        
        self.frame = frame
        
        backgroundColor = UIColor.clear.cgColor
        strokeColor = UIColor.lightGray.cgColor
        fillColor = UIColor.clear.cgColor
        lineWidth = 1
        
        update()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func update() {
        let rect = CGRect(origin: topLeft, size: CGSize(width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y))
        self.path = CGPath(rect: rect, transform: nil)
    }
}
