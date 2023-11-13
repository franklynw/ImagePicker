//
//  Overlays.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import UIKit


struct Overlays {
    
    @discardableResult
    static func addTopButton(to view: UIView, with image: UIImage?, diameter: CGFloat, action: @escaping () -> (), additionalConstraints: (UIButton) -> ()) -> UIButton {
        
        let button = button(for: view, with: image, action: action)
        
        button.widthAnchor.constraint(equalToConstant: diameter).isActive = true
        button.heightAnchor.constraint(equalToConstant: diameter).isActive = true
        button.topAnchor.constraint(equalTo: view.topAnchor, constant: 20).isActive = true
        
        additionalConstraints(button)
        
        return button
    }
    
    static func addOtherButton(to view: UIView, with image: UIImage?, diameter: CGFloat, action: @escaping () -> ()) -> UIButton {
        
        let button = button(for: view, with: image, action: action)
        
        button.widthAnchor.constraint(equalToConstant: diameter).isActive = true
        button.heightAnchor.constraint(equalToConstant: diameter).isActive = true
        
        return button
    }
    
    static func addCircle(to view: UIView, diameter: CGFloat) -> UIImageView {
        
        let circle = UIImageView(image: UIImage(systemName: "circle"))
        
        circle.tintColor = .lightGray
        circle.contentMode = .scaleAspectFit
        
        view.addSubview(circle)
        
        circle.frame = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
        
        return circle
    }
    
    private static func button(for view: UIView, with image: UIImage?, action: @escaping () -> ()) -> UIButton {
        
        let buttonAction = UIAction { _ in action() }
        let button = UIButton(primaryAction: buttonAction)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.setImage(image, for: UIControl.State())
        button.tintColor = .lightGray
        button.contentMode = .scaleAspectFit
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        
        view.addSubview(button)
        
        return button
    }
}
