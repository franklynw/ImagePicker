//
//  UIImage+Extensions.swift
//  
//
//  Created by Franklyn Weber on 19/02/2021.
//

import UIKit


extension UIImage {
    
    enum Aspect {
        case portrait
        case landscape
    }
    
    func withCorrectedRotation(desiredAspect: Aspect? = nil) -> UIImage {
        
        func rotatedIfNecessary(_ image: UIImage) -> UIImage {
            
            guard let desiredAspect = desiredAspect, (desiredAspect == .portrait && image.size.width > image.size.height) || (desiredAspect == .landscape && image.size.width < image.size.height) else {
                return image
            }
            
            // we have no idea whether to rotate cw or ccw so just do 90 degrees
            
            return image.rotated(by: .pi / 2)
        }
        
        if imageOrientation == .up {
            return rotatedIfNecessary(self)
        }
        
        var transform = CGAffineTransform.identity
        
        let width = size.width
        let height = size.height
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: width, y: height)
            transform = transform.rotated(by: .pi)
            break
            
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.rotated(by: .pi / 2)
            break
            
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: height)
            transform = transform.rotated(by: -.pi / 2)
            break
            
        default:
            break
        }
        
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            break
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0);
            transform = transform.scaledBy(x: -1, y: 1)
            break
            
        default:
            break
        }
        
        guard let cgImage = cgImage, let colorSpace = cgImage.colorSpace else {
            return self
        }
        guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: cgImage.bitmapInfo.rawValue) else {
            return self
        }
        
        context.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: height, height: width))
            break

        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            break
        }
        
        guard let image = context.makeImage() else {
            return self
        }
        
        let correctedImage = UIImage(cgImage: image)
        
        return rotatedIfNecessary(correctedImage)
    }
    
    func rotated(by radians: CGFloat) -> UIImage {
        
        guard let orientation = CGImagePropertyOrientation(rawValue: UInt32(imageOrientation.rawValue)) else {
            return self
        }
        guard let image = CIImage(image: self)?.oriented(orientation) else {
            return self
        }
        
        let rotation = CGAffineTransform(rotationAngle: radians)
        let output = image.transformed(by: rotation)
        
        guard let cgImage = CIContext().createCGImage(output, from: output.extent) else {
            return self
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func scaled(to scale: CGFloat) -> UIImage {
        
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        let scaledRect = CGRect(origin: .zero, size: scaledSize)
        
        UIGraphicsBeginImageContextWithOptions(scaledRect.size, false, self.scale)
        draw(in: scaledRect)
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage ?? self
    }
    
    func cropped(with insets: UIEdgeInsets) -> UIImage {
        
        guard let cgImage = cgImage else {
            return self
        }
        
        let croppedRect = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: size.width - insets.left - insets.right, height: size.height - insets.top - insets.bottom))
        
        guard let cropped = cgImage.cropping(to: croppedRect) else {
            return self
        }
        
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}
