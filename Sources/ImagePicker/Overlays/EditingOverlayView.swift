//
//  EditingOverlayView.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import SwiftUI


final class EditingOverlayView: UIView {
    
    private let diameter: CGFloat = 40
    private let minBoxSize: CGFloat = 100
    private let minVerticalPadding: CGFloat = 100
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
    private var translate: CGSize = .zero
    
    private var isAdjusting = false
    private var isCorrecting = false
    
    private var rotateTransform: CGAffineTransform = .identity {
        didSet {
            transform()
        }
    }
    private var scaleTransform: CGAffineTransform = .identity {
        didSet {
            transform()
        }
    }
    private var translateTransform: CGAffineTransform = .identity {
        didSet {
            transform()
        }
    }
    
    enum Move {
        case topLeft(CGSize)
        case bottomRight(CGSize)
        case image
    }
    
    
    init<T>(frame: CGRect, item: Binding<T?>, screenImage: UIImage, originalImage: @autoclosure @escaping () -> UIImage, retake: @escaping () -> (), done: @escaping (Result<PHImage, ImagePickerError>) -> ()) {
        
        aspectRatio = screenImage.size.height / screenImage.size.width
        
        super.init(frame: frame)
        
        
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
        dragGestureRecognizer.delegate = self
        interactionView.addGestureRecognizer(dragGestureRecognizer)
        
        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(rotate))
        rotationGestureRecognizer.delegate = self
        interactionView.addGestureRecognizer(rotationGestureRecognizer)
        
        let zoomGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(zoom))
        zoomGestureRecognizer.delegate = self
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
        
        let resetButton = Overlays.otherButton(with: UIImage(systemName: "arrow.uturn.backward.circle.fill"), diameter: 60) { [weak self] in
            self?.reset()
        }
        
        let buttonContainer = UIImageView(image: UIImage(systemName: "circle.fill"))
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.backgroundColor = .clear
        buttonContainer.tintColor = .lightGray
        buttonContainer.isUserInteractionEnabled = true
        
        let sizeBoxToImageButton = Overlays.button(with: UIImage(systemName: "rectangle.expand.vertical")) { [weak self] in
            self?.sizeBoxToVisibleImage()
        }
        sizeBoxToImageButton.tintColor = .black
        let imageConfig = UIImage.SymbolConfiguration(weight: .semibold)
        sizeBoxToImageButton.setPreferredSymbolConfiguration(imageConfig, forImageIn: UIControl.State())
        
        buttonContainer.addSubview(sizeBoxToImageButton)
        sizeBoxToImageButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor, constant: 8).isActive = true
        sizeBoxToImageButton.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor, constant: -8).isActive = true
        sizeBoxToImageButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor, constant: 8).isActive = true
        sizeBoxToImageButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -8).isActive = true
        buttonContainer.widthAnchor.constraint(equalToConstant: 60).isActive = true
        buttonContainer.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        let bottomButtons = UIStackView(arrangedSubviews: [resetButton, buttonContainer])
        bottomButtons.translatesAutoresizingMaskIntoConstraints = false
        bottomButtons.axis = .horizontal
        bottomButtons.spacing = 20
        interactionView.addSubview(bottomButtons)
        
        bottomButtons.centerXAnchor.constraint(equalTo: interactionView.centerXAnchor).isActive = true
        bottomButtons.bottomAnchor.constraint(equalTo: interactionView.safeAreaLayoutGuide.bottomAnchor).isActive = true
        
        
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
        let translate = gestureRecognizer.translation(in: self)
        
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
                return
            }
            
            isAdjusting = true
            move = .image
            
        case .changed:
            
            guard let move = move else {
                return
            }
            
            switch move {
            case .topLeft(let offset):
                
                let bottomRight = boxInsets.bottomRight(in: frame)
                let x = max(min(location.x - offset.width, bottomRight.x - minBoxSize), 0)
                let y = max(min(location.y - offset.height, bottomRight.y - minBoxSize), minVerticalPadding)
                
                let topLeft = CGPoint(x: x, y: y)
                
                maskLayer.topLeft = topLeft
                boxLayer.topLeft = topLeft
                topLeftCircle.center = topLeft
                boxInsets.topLeft = topLeft
                
            case .bottomRight(let offset):
                
                let x = min(max(location.x - offset.width, boxInsets.left + minBoxSize), frame.width)
                let y = min(max(location.y - offset.height, boxInsets.top + minBoxSize), frame.height - minVerticalPadding)
                
                let bottomRight = CGPoint(x: x, y: y)
                
                maskLayer.bottomRight = bottomRight
                boxLayer.bottomRight = bottomRight
                bottomRightCircle.center = bottomRight
                boxInsets.bottomRight = CGPoint(x: frame.width - bottomRight.x, y: frame.height - bottomRight.y)
                
            case .image:
                
                let actualTranslate = CGSize(width: translate.x + self.translate.width, height: translate.y + self.translate.height)
                translateTransform = CGAffineTransform(translationX: actualTranslate.width, y: actualTranslate.height)
            }
            
            UIView.animate(withDuration: 0.1) {
                self.layoutIfNeeded()
            }
            
        default:
            
            if case .image = move {
                isAdjusting = false
                self.translate = CGSize(width: translate.x + self.translate.width, height: translate.y + self.translate.height)
                correctAfterUserAdjustments()
            }
            
            move = nil
        }
    }
    
    @objc
    private func rotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        
        let rotation = gestureRecognizer.rotation
        
        switch gestureRecognizer.state {
        case .began:
            isAdjusting = true
        case .changed:
            rotateTransform = CGAffineTransform(rotationAngle: rotation + self.rotation)
        default:
            isAdjusting = false
            self.rotation += rotation
            correctAfterUserAdjustments()
        }
    }
    
    @objc
    private func zoom(_ gestureRecognizer: UIPinchGestureRecognizer) {
        
        let scale = gestureRecognizer.scale
        
        switch gestureRecognizer.state {
        case .began:
            isAdjusting = true
        case .changed:
            let actualScale = self.scale * scale
            scaleTransform = CGAffineTransform(scaleX: actualScale, y: actualScale)
        default:
            isAdjusting = false
            self.scale *= scale
            correctAfterUserAdjustments()
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
            
            let top = max(0, (insets.top - self.translate.height) * ratio + yAdjustment)
            let left = max(0, (insets.left - self.translate.width) * ratio + xAdjustment)
            let bottom = max(0, (insets.bottom + self.translate.height) * ratio + yAdjustment)
            let right = max(0, (insets.right + self.translate.width) * ratio + xAdjustment)
            
            let croppedImage = rotatedImage.cropped(with: UIEdgeInsets(top: top, left: left, bottom: bottom, right: right))
            
            DispatchQueue.main.async {
                completion(croppedImage)
            }
        }
    }
    
    private func transform() {
        imageView.transform = rotateTransform.concatenating(scaleTransform).concatenating(translateTransform)
    }
    
    private func correctAfterUserAdjustments() {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !self.isAdjusting {
                self.doCorrections()
            }
        }
    }
    
    private func doCorrections() {
        
        guard !isCorrecting else {
            return
        }
        
        let imageFrame = imageView.frame
        
        guard imageFrame.width < minBoxSize ||
          imageFrame.height < minBoxSize ||
          imageFrame.maxX < minBoxSize ||
          imageFrame.minX > frame.width - minBoxSize ||
          imageFrame.maxY < minVerticalPadding + minBoxSize ||
          imageFrame.minY > frame.height - minVerticalPadding - minBoxSize else {
            return
        }
        
        isCorrecting = true
        
        let originalImageHeight = frame.width * aspectRatio
        self.scale = max(max(minBoxSize / frame.width, minBoxSize / originalImageHeight), self.scale)
        
        var translateX = max(minBoxSize - imageFrame.maxX, 0)
        if translateX == 0 {
            translateX = min(frame.width - minBoxSize - imageFrame.minX, 0)
        }
        var translateY = max(minVerticalPadding + minBoxSize - imageFrame.maxY, 0)
        if translateY == 0 {
            translateY = min(frame.height - minVerticalPadding - minBoxSize - imageFrame.minY, 0)
        }
        translate = CGSize(width: translate.width + translateX, height: translate.height + translateY)
        
        UIView.animate(withDuration: 0.4) {
            self.translateTransform = CGAffineTransform(translationX: self.translate.width, y: self.translate.height)
            self.scaleTransform = CGAffineTransform(scaleX: self.scale, y: self.scale)
        } completion: { _ in
            self.isCorrecting = false
        }
    }
    
    private func sizeBoxToVisibleImage() {
        
        let imageFrame = imageView.frame
        let top = max(imageFrame.origin.y, minVerticalPadding)
        let left = max(imageFrame.origin.x, 0)
        let bottom = max(frame.maxY - imageFrame.maxY, minVerticalPadding)
        let right = max(frame.maxX - imageFrame.maxX, 0)
        
        boxInsets = .init(top: top, left: left, bottom: bottom, right: right)
        
        let topLeft = boxInsets.topLeft
        let bottomRight = boxInsets.bottomRight(in: frame)
        
        UIView.transition(with: self, duration: 0.5, options: .transitionCrossDissolve) {
            self.maskLayer.topLeft = topLeft
            self.boxLayer.topLeft = topLeft
            self.maskLayer.bottomRight = bottomRight
            self.boxLayer.bottomRight = bottomRight
        }
        
        UIView.animate(withDuration: 0.4, delay: 0.1) {
            self.topLeftCircle.center = topLeft
            self.bottomRightCircle.center = bottomRight
        }
    }
    
    private func reset() {
        
        boxInsets = originalBoxInsets
        rotation = 0
        scale = 1
        translate = .zero
        
        let topLeft = boxInsets.topLeft
        let bottomRight = boxInsets.bottomRight(in: frame)
        
        self.maskLayer.topLeft = topLeft
        self.boxLayer.topLeft = topLeft
        self.maskLayer.bottomRight = bottomRight
        self.boxLayer.bottomRight = bottomRight
        
        UIView.transition(with: self, duration: 0.5, options: .transitionCrossDissolve) {
            self.maskLayer.topLeft = topLeft
            self.boxLayer.topLeft = topLeft
            self.maskLayer.bottomRight = bottomRight
            self.boxLayer.bottomRight = bottomRight
        }
        
        UIView.animate(withDuration: 0.4, delay: 0.1) {
            self.scaleTransform = .identity
            self.rotateTransform = .identity
            self.translateTransform = .identity
            self.topLeftCircle.center = topLeft
            self.bottomRightCircle.center = bottomRight
        }
    }
}


extension EditingOverlayView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
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
