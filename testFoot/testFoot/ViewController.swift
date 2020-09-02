//
//  ViewController.swift
//  test
//
//  Created by Phoebe Tsui on 1/9/20.
//  Copyright © 2020 Phoebe Tsui. All rights reserved.
//

import UIKit
import CoreML
import Vision
import ImageIO

class ViewController: UIViewController {
    
    
    @IBOutlet weak var modeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var resultsLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var resultsView: UIView!
    
//    resultsView(draw.ishidden)
    // MARK: - Image Classification
    
    /// - Tag: MLModelSetup
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            /*
             Use the Swift class `MobileNet` Core ML generates from the model.
             To use a different Core ML classifier model, add it to the project
             and replace `MobileNet` with that model's generated Swift class.
             */
            let model = try VNCoreMLModel(for: classificationModel().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    lazy var detectionRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: detectionModel().model)
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processDetections(for: request, error: error)
            })
            request.imageCropAndScaleOption = .scaleFit
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    /// - Tag: PerformRequests
    func updateClassifications(for image: UIImage) {
        
        resultsView.isHidden = false
        resultsLabel.text = "Classifying..."
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                /*
                 This handler catches general image processing errors. The `classificationRequest`'s
                 completion handler `processClassifications(_:error:)` catches errors specific
                 to processing that request.
                 */
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    func updateDetections(for image: UIImage) {
        
        resultsView.isHidden = false
        resultsLabel.text = "Detecting..."
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.detectionRequest])
            } catch {
                print("Failed to perform detection.\n\(error.localizedDescription)")
            }
        }
    }
    
    /// Updates the UI with the results of the classification.
    /// - Tag: ProcessClassifications
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.resultsLabel.text = "Unable to classify image.\n\(error!.localizedDescription)"
                return
            }
            // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
            let classifications = results as! [VNClassificationObservation]
            
            if classifications.isEmpty {
                self.resultsLabel.text = "Nothing recognized."
            } else {
                // Display top classifications ranked by confidence in the UI.
                let topClassifications = classifications.prefix(2)
                let descriptions = topClassifications.map { classification in
//                    Formats the classification for display; e.g. "(0.37) cliff, drop, drop-off".
//                    return String(format: "  (%.2f) %@", classification.confidence, classification.identifier)
                    return String(format: "Confidence of %@: %.2f ", classification.identifier, classification.confidence)
                }
                self.resultsLabel.text = "Classification:\n" + descriptions.joined(separator: "\n")
                //                if self.modeSegmentedControl.selectedSegmentIndex == 0 {
                //                    self.pressedLabel.text = "Classification:\n" + descriptions.joined(separator: "\n")
                //                }
            }
        }
    }
//    prototypeUIKit
    func processDetections(for request: VNRequest, error: Error?) {
        
        DispatchQueue.main.async {
            
//            print(self.pressedLabel.text ?? "")
            guard let results = request.results else {
                print("Unable to detect anything.\n\(error!.localizedDescription)")
                return
            }
            
            let detections = results as! [VNRecognizedObjectObservation]
            if detections.isEmpty {
                self.resultsLabel.text = "Nothing detected."
            } else {
                self.drawDetectionsOnPreview(detections: detections)
                //            if self.modeSegmentedControl.selectedSegmentIndex == 1 {
                //                self.drawDetectionsOnPreview(detections: detections)
                //            }
            }
        }
    }
    
    func drawDetectionsOnPreview(detections: [VNRecognizedObjectObservation]) {
        guard let image = self.imageView?.image else {
            return
        }
        
        let imageSize = image.size
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)
        
        image.draw(at: CGPoint.zero)
        
        var area = ""
        if detections.count > 1 { area = "areas"} else { area = "area" }
        resultsLabel.text = "Total \(String(detections.count)) abnormal \(area) detected."
        
        for detection in detections {
            
//            print(detection.labels.map({"\($0.identifier) confidence: \($0.confidence)"}).joined(separator: "\n"))
//            print("------------")
            
            // The coordinates are normalized to the dimensions of the processed image, with the origin at the image's lower-left corner.
            let boundingBox = detection.boundingBox
            let rectangle = CGRect(x: boundingBox.minX*image.size.width, y: (1-boundingBox.minY-boundingBox.height)*image.size.height, width: boundingBox.width*image.size.width, height: boundingBox.height*image.size.height)
            UIColor(red: 1, green: 0, blue: 0, alpha: 0.4).setFill()
            UIRectFillUsingBlendMode(rectangle, CGBlendMode.normal)
        }
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.imageView?.image = newImage
    }
    
    // MARK: - Photo Actions
    @IBAction func takePicture(_ sender: Any) {
        //        let pickerController = UIImagePickerController()
        //        pickerController.sourceType = UIImagePickerController.SourceType.camera
        //        pickerController.delegate = self
        //        present(pickerController, animated: true, completion: nil)
        
        // Show options for the source picker only if the camera is available.
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoPicker(sourceType: .photoLibrary)
            return
        }
        
        let photoSourcePicker = UIAlertController()
        let takePhoto = UIAlertAction(title: "Take Photo", style: .default) { [unowned self] _ in
            self.presentPhotoPicker(sourceType: .camera)
        }
        let choosePhoto = UIAlertAction(title: "Choose Photo", style: .default) { [unowned self] _ in
            self.presentPhotoPicker(sourceType: .photoLibrary)
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        photoSourcePicker.addAction(takePhoto)
        photoSourcePicker.addAction(choosePhoto)
        photoSourcePicker.addAction(cancel)
        
        present(photoSourcePicker, animated: true)
        
    }
    
    func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }
    
    @IBAction func changeMode(_ sender: Any) {
        resultsLabel.text = nil
        imageView.image = nil
        resultsView.isHidden = true
    }
    
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - Handling Image Picker Selection
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true, completion: nil)
        
        // We always expect `imagePickerController(:didFinishPickingMediaWithInfo:)` to supply the original image.
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as! UIImage? else {
            
            print(info[UIImagePickerController.InfoKey.originalImage]!)
            let title = "Error"
            let message = "An error occured when loading image, please choose another image."
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let ok = UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in NSLog("The \"Error loading image\" alert occured.") })
            alert.addAction(ok)
            self.present(alert, animated: true, completion: nil)
            
            return
        }
        imageView.image = image
        
        if modeSegmentedControl.selectedSegmentIndex == 0 {
            updateClassifications(for: image)
        }else if modeSegmentedControl.selectedSegmentIndex == 1 {
            updateDetections(for: image)
        }
        
    }
    
    //    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    //        print("The camera has been closed.")
    //    }
}

