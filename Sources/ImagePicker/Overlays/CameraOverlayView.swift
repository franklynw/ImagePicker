//
//  CameraOverlayView.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import SwiftUI


final class CameraOverlayView: UIView {
    
    private let diameter: CGFloat = 35
    private let takePhotoButtonDiameter: CGFloat = 70
    
    
    init<T>(frame: CGRect, item: Binding<T?>, cycleFlash: @escaping () -> (UIImagePickerController.CameraFlashMode), capture: @escaping () -> (), done: Binding<Result<PHImage, ImagePickerError>?>) {
        
        super.init(frame: frame)
        
        Overlays.addTopButton(to: self, with: UIImage(systemName: "xmark.circle.fill"), diameter: diameter, action: {
            done.wrappedValue = .failure(.cancelled)
            item.wrappedValue = nil
        }) {
            $0.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        }
        
        var captureButton: UIButton?
        
        captureButton = Overlays.addTopButton(to: self, with: UIImage(systemName: "bolt.slash.circle.fill"), diameter: diameter, action: {
            let mode = cycleFlash()
            captureButton?.setImage(UIImage(systemName: mode.systemImage), for: UIControl.State())
        }) {
            $0.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20).isActive = true
        }
        
        let buttonAction = UIAction { _ in capture() }
        let button = UIButton(primaryAction: buttonAction)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.setImage(UIImage(systemName: "livephoto"), for: UIControl.State())
        button.tintColor = .lightGray
        button.contentMode = .scaleAspectFit
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        
        addSubview(button)
        
        button.widthAnchor.constraint(equalToConstant: takePhotoButtonDiameter).isActive = true
        button.heightAnchor.constraint(equalToConstant: takePhotoButtonDiameter).isActive = true
        button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20).isActive = true
        button.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
