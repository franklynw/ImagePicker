//
//  EditingOverlayView.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import SwiftUI


final class EditingOverlayView: UIView {
    
    private let diameter: CGFloat = 35
    private let minBoxSize: CGFloat = 100
    private let aspectRatio: CGFloat
    
    private var originalBoxInsets = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
    private var boxInsets: UIEdgeInsets!
    
    private var imageView: UIImageView!
    private var move: Move?
    private var maskLayer: MaskLayer!
    private var boxLayer: BoxLayer!
    private var topLeftCircle: UIImageView!
    private var bottomRightCircle: UIImageView!
    private var spinner: Spinner!
    
    private var rotation: CGFloat = 0
    private var scale: CGFloat = 1
    
    private var rotateTransform: CGAffineTransform = .init(rotationAngle: 0) {
        didSet {
            imageView.transform = rotateTransform.concatenating(scaleTransform)
        }
    }
    private var scaleTransform: CGAffineTransform = .init(scaleX: 1, y: 1) {
        didSet {
            imageView.transform = rotateTransform.concatenating(scaleTransform)
        }
    }
    
    enum Move {
        case topLeft(CGSize)
        case bottomRight(CGSize)
    }
    
    
    init<T>(frame: CGRect, item: Binding<T?>, screenImage: UIImage, originalImage: @autoclosure @escaping () -> UIImage, retake: @escaping () -> (), done: @escaping (Result<PHImage, ImagePickerError>) -> ()) {
        
        aspectRatio = screenImage.size.height / screenImage.size.width
        
        super.init(frame: frame)
        
        let topObscureView = UIView()
        topObscureView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(topObscureView)
        
        topObscureView.backgroundColor = .black
        topObscureView.translatesAutoresizingMaskIntoConstraints = false
        topObscureView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        topObscureView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        topObscureView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        topObscureView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        let bottomObscureView = UIView()
        bottomObscureView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(bottomObscureView)
        
        bottomObscureView.backgroundColor = .black
        bottomObscureView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        bottomObscureView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        bottomObscureView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        bottomObscureView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        
        let imageView = UIImageView(image: screenImage)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        imageView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        imageView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        imageView.heightAnchor.constraint(equalTo: widthAnchor, multiplier: aspectRatio).isActive = true
        
        self.imageView = imageView
        
        let imageHeight = frame.width * aspectRatio
        let imageSize = CGSize(width: frame.width, height: frame.width * aspectRatio)
        let imageFrame = CGRect(origin: CGPoint(x: 0, y: (frame.height - imageHeight) / 2), size: imageSize)
        
        boxInsets = originalBoxInsets
        boxInsets = .init(top: imageFrame.minY + boxInsets.top, left: boxInsets.left, bottom: frame.height - imageFrame.maxY + boxInsets.bottom, right: boxInsets.right)
        originalBoxInsets = boxInsets
        
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
        
        let dragGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(dragged))
        interactionView.addGestureRecognizer(dragGestureRecognizer)
        
        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(rotate))
        interactionView.addGestureRecognizer(rotationGestureRecognizer)
        
        let zoomGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(zoom))
        interactionView.addGestureRecognizer(zoomGestureRecognizer)
        
        let closeButton = Overlays.addTopButton(to: interactionView, with: UIImage(systemName: "xmark.circle.fill"), diameter: diameter, action: {
            done(.failure(.cancelled))
            item.wrappedValue = nil
        }) {
            $0.leadingAnchor.constraint(equalTo: interactionView.leadingAnchor, constant: 20).isActive = true
        }
        Overlays.addTopButton(to: interactionView, with: UIImage(systemName: "camera.circle.fill"), diameter: diameter, action: retake) {
            $0.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 20).isActive = true
        }
        Overlays.addTopButton(to: interactionView, with: UIImage(systemName: "checkmark.circle.fill"), diameter: diameter, action: { [weak self] in
            
            guard let self = self else {
                done(.failure(.noSelf))
                return
            }
            
            self.spinner.startAnimating()
            self.layoutIfNeeded()
            
            let correctedInsets = UIEdgeInsets(top: self.boxInsets.top - imageFrame.minY, left: self.boxInsets.left, bottom: self.boxInsets.bottom - (frame.height - imageFrame.maxY), right: self.boxInsets.right)
            self.processImage(originalImage(), insets: correctedInsets) { croppedImage in
                done(.success(.init(image: croppedImage, metadata: .init(location: nil, creationDate: nil))))
                item.wrappedValue = nil
            }
            
        }) {
            $0.trailingAnchor.constraint(equalTo: interactionView.trailingAnchor, constant: -20).isActive = true
        }
        
        let resetButton = Overlays.addOtherButton(to: interactionView, with: UIImage(systemName: "arrow.uturn.backward.circle.fill"), diameter: 80) { [weak self] in
            self?.reset()
        }
        resetButton.centerXAnchor.constraint(equalTo: interactionView.centerXAnchor).isActive = true
        resetButton.bottomAnchor.constraint(equalTo: interactionView.bottomAnchor, constant: -20).isActive = true
        
        let spinner = Spinner()
        addSubview(spinner)
        
        spinner.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
        self.spinner = spinner
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
    private func rotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        
        let rotation = gestureRecognizer.rotation
        
        switch gestureRecognizer.state {
        case .began:
            break
        case .changed:
            rotateTransform = CGAffineTransform(rotationAngle: rotation + self.rotation)
        default:
            self.rotation += rotation
        }
    }
    
    @objc
    private func zoom(_ gestureRecognizer: UIPinchGestureRecognizer) {
        
        let scale = gestureRecognizer.scale
        
        switch gestureRecognizer.state {
        case .began:
            break
        case .changed:
            let actualScale = self.scale * scale
            scaleTransform = CGAffineTransform(scaleX: actualScale, y: actualScale)
        default:
            self.scale *= scale
        }
    }
    
    private func processImage(_ image: UIImage, insets: UIEdgeInsets, completion: @escaping (UIImage) -> ()) {
        
        let width = frame.size.width
        
        DispatchQueue.global(qos: .background).async {
            
            let scaledImage = image.scaled(to: self.scale)
            let rotatedImage = scaledImage.rotated(by: -self.rotation)
            
            let xAdjustment = (rotatedImage.size.width - image.size.width) / 2
            let yAdjustment = (rotatedImage.size.height - image.size.height) / 2
            
            let ratio = image.size.width / width
            
            let top = insets.top * ratio + yAdjustment
            let left = insets.left * ratio + xAdjustment
            let bottom = insets.bottom * ratio + yAdjustment
            let right = insets.right * ratio + xAdjustment
            
            let croppedImage = rotatedImage.cropped(with: UIEdgeInsets(top: top, left: left, bottom: bottom, right: right))
            
            DispatchQueue.main.async {
                completion(croppedImage)
            }
        }
    }
    
    private func reset() {
        
        boxInsets = originalBoxInsets
        rotation = 0
        scale = 1
        
        let topLeft = boxInsets.topLeft
        let bottomRight = boxInsets.bottomRight(in: frame)
        
        UIView.transition(with: self, duration: 0.5, options: .transitionCrossDissolve) {
            self.maskLayer.topLeft = topLeft
            self.boxLayer.topLeft = topLeft
            self.maskLayer.bottomRight = bottomRight
            self.boxLayer.bottomRight = bottomRight
        } completion: { _ in
            // nothing
        }
        
        UIView.animate(withDuration: 0.5) {
            self.scaleTransform = .init(scaleX: 1, y: 1)
            self.rotateTransform = .init(rotationAngle: 0)
            self.topLeftCircle.center = topLeft
            self.bottomRightCircle.center = bottomRight
        }
    }
}


extension CGRect {
    
    var topLeft: CGPoint {
        CGPoint(x: minX, y: minY)
    }
    
    var bottomRight: CGPoint {
        CGPoint(x: maxX, y: maxY)
    }
}


class Spinner: UIView {
    
    private var spinner: UIActivityIndicatorView!
    
    init() {
        
        super.init(frame: .zero)
        
        translatesAutoresizingMaskIntoConstraints = false
        
        backgroundColor = .black.withAlphaComponent(0.7)
        layer.cornerRadius = 38
        widthAnchor.constraint(equalToConstant: 76).isActive = true
        heightAnchor.constraint(equalToConstant: 76).isActive = true
        alpha = 0
        
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .white
        spinner.hidesWhenStopped = true
        
        addSubview(spinner)
        
        spinner.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 1).isActive = true // slightly off-centre
        spinner.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1).isActive = true
        
        self.spinner = spinner
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func startAnimating() {
        
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        } completion: { _ in
            self.spinner.startAnimating()
        }
    }
    
    func stopAnimating() {
        
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0
        } completion: { _ in
            self.spinner.stopAnimating()
        }
    }
}
