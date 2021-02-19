//
//  EditingOverlayView.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import SwiftUI


class EditingOverlayView<T: Identifiable>: UIView {
    
    private let diameter: CGFloat = 35
    private let minBoxSize: CGFloat = 100
    private var boxInsets = UIEdgeInsets(top: 90, left: 40, bottom: 40, right: 40)
    
    private var imageView: UIImageView!
    private var move: Move?
    private var maskLayer: MaskLayer!
    private var boxLayer: BoxLayer!
    private var topLeftCircle: UIImageView!
    private var bottomRightCircle: UIImageView!
    
    private var rotation: CGFloat = 0
    
    enum Move {
        case topLeft(CGSize)
        case bottomRight(CGSize)
    }
    
    
    init(frame: CGRect, item: Binding<T?>, initialImage: UIImage, retake: @escaping () -> (), done: Binding<Result<UIImage, ImagePickerError>?>) {
        
        super.init(frame: frame)
        
        let correctedImage = initialImage.withCorrectedRotation(desiredAspect: .portrait)
        let imageView = UIImageView(image: correctedImage)
        addSubview(imageView)
        imageView.pinEdgesToSuperView()
        
        self.imageView = imageView
        
        let boxSize = CGSize(width: frame.width - boxInsets.left - boxInsets.right, height: frame.height - boxInsets.top - boxInsets.bottom)
        
        let maskView = UIView()
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        addSubview(maskView)
        maskView.pinEdgesToSuperView()
        
        maskLayer = MaskLayer(frame: frame, initialMask: CGRect(origin: boxInsets.topLeft, size: boxSize))
        
        maskView.layer.mask = maskLayer
        
        
        let controlsView = UIView()
        controlsView.backgroundColor = .clear
        addSubview(controlsView)
        controlsView.pinEdgesToSuperView()
        
        topLeftCircle = Overlays.addCircle(to: controlsView, diameter: diameter)
        topLeftCircle.center = boxInsets.topLeft
        
        bottomRightCircle = Overlays.addCircle(to: controlsView, diameter: diameter)
        bottomRightCircle.center = boxInsets.bottomRight(in: frame)
        
        boxLayer = BoxLayer(frame: frame, initialMask: CGRect(origin: boxInsets.topLeft, size: boxSize))
        controlsView.layer.addSublayer(boxLayer)
        
        
        let interactionView = UIView()
        interactionView.backgroundColor = .clear
        addSubview(interactionView)
        interactionView.pinEdgesToSuperView()
        
        let dragGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
        interactionView.addGestureRecognizer(dragGestureRecognizer)
        
//        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(rotate(_:)))
//        interactionView.addGestureRecognizer(rotationGestureRecognizer)
        
        let closeButton = Overlays.addTopButton(to: interactionView, with: UIImage(systemName: "xmark.circle.fill"), diameter: diameter, action: {
            done.wrappedValue = .failure(.cancelled)
            item.wrappedValue = nil
        }) {
            $0.leadingAnchor.constraint(equalTo: interactionView.leadingAnchor, constant: 20).isActive = true
        }
        Overlays.addTopButton(to: interactionView, with: UIImage(systemName: "camera.circle.fill"), diameter: diameter, action: retake) {
            $0.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 20).isActive = true
        }
        Overlays.addTopButton(to: interactionView, with: UIImage(systemName: "checkmark.circle.fill"), diameter: diameter, action: { [weak self] in
            
            guard let self = self else {
                done.wrappedValue = .failure(.noSelf)
                return
            }
            
            let croppedImage = self.processImage(correctedImage)
            
//            let imageView = UIImageView(image: croppedImage.scaled(to: 0.05))
//            interactionView.addSubview(imageView)
//            imageView.center = CGPoint(x: frame.width / 2, y: frame.height / 2)
            
            done.wrappedValue = .success(croppedImage)
            item.wrappedValue = nil
        }) {
            $0.trailingAnchor.constraint(equalTo: interactionView.trailingAnchor, constant: -20).isActive = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    private func dragged(_ gestureRecognizer: UIPanGestureRecognizer) {
        
        let location = gestureRecognizer.location(in: self)
        
        switch gestureRecognizer.state {
        case .began:
            
            let topLeftBox = CGRect(origin: boxInsets.topLeft, size: .zero).insetBy(dx: diameter * -2, dy: diameter * -2)
            
            if topLeftBox.contains(location) {
                let offset = CGSize(width: location.x - boxInsets.left, height: location.y - boxInsets.top)
                move = .topLeft(offset)
                return
            }
            
            let bottomRight = boxInsets.bottomRight(in: frame)
            let bottomRightBox = CGRect(origin: bottomRight, size: .zero).insetBy(dx: diameter * -2, dy: diameter * -2)
            
            if bottomRightBox.contains(location) {
                let offset = CGSize(width: location.x - bottomRight.x, height: location.y - bottomRight.y)
                move = .bottomRight(offset)
            }
            
        case .changed:
            
            guard let move = move else {
                return
            }
            
            switch move {
            case .topLeft(let offset):
                
                let bottomRight = boxInsets.bottomRight(in: frame)
                let x = max(min(location.x - offset.width, bottomRight.x - minBoxSize), 0)
                let y = max(min(location.y - offset.height, bottomRight.y - minBoxSize), 0)
                
                let topLeft = CGPoint(x: x, y: y)
                
                maskLayer.topLeft = topLeft
                boxLayer.topLeft = topLeft
                topLeftCircle.center = topLeft
                boxInsets.topLeft = topLeft
                
            case .bottomRight(let offset):
                
                let x = min(max(location.x - offset.width, boxInsets.left + minBoxSize), frame.width)
                let y = min(max(location.y - offset.height, boxInsets.top + minBoxSize), frame.height)
                
                let bottomRight = CGPoint(x: x, y: y)
                
                maskLayer.bottomRight = bottomRight
                boxLayer.bottomRight = bottomRight
                bottomRightCircle.center = bottomRight
                boxInsets.bottomRight = CGPoint(x: frame.width - bottomRight.x, y: frame.height - bottomRight.y)
            }
            
            UIView.animate(withDuration: 0.1) {
                self.layoutIfNeeded()
            }
            
        default:
            move = nil
        }
    }
    
    @objc
    func rotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        
        let rotation = gestureRecognizer.rotation
        
        switch gestureRecognizer.state {
        case .began:
            break
        case .changed:
            
            let rotateTransform = CGAffineTransform(rotationAngle: rotation + self.rotation)
            
            imageView.transform = rotateTransform
            
        default:
            self.rotation += rotation
        }
    }
    
    private func processImage(_ initialImage: UIImage) -> UIImage {
        
        let imageSize = initialImage.size
        let ratio = frame.height / imageSize.height

        let top = boxInsets.top / ratio
        let left = boxInsets.left / ratio
        let bottom = boxInsets.bottom / ratio
        let right = boxInsets.right / ratio

        let croppedImage = initialImage.cropped(with: UIEdgeInsets(top: top, left: left, bottom: bottom, right: right))

        return croppedImage
    }
}
