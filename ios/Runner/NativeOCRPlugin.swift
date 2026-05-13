import Flutter
import UIKit
import Vision

/// Flutter ↔ iOS Vision framework bridge.
///
/// Channel: "com.nutrivision/ocr"
/// Method : "recognizeText"
///   Args : { "imageBytes": FlutterStandardTypedData (JPEG), "rotation": Int }
///   Returns: [[String: Any]] — array of text block maps
final class NativeOCRPlugin: NSObject, FlutterPlugin {

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.nutrivision/ocr",
            binaryMessenger: registrar.messenger()
        )
        let instance = NativeOCRPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "recognizeText" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard
            let args = call.arguments as? [String: Any],
            let typedData = args["imageBytes"] as? FlutterStandardTypedData,
            let uiImage = UIImage(data: typedData.data),
            let cgImage = uiImage.cgImage
        else {
            result(FlutterError(code: "INVALID_IMAGE",
                                message: "Cannot decode JPEG",
                                details: nil))
            return
        }

        // Honour device orientation via the image's natural orientation
        let orientation = cgImagePropertyOrientation(from: uiImage)
        let requestHandler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation,
            options: [:]
        )

        let request = VNRecognizeTextRequest { req, err in
            guard err == nil,
                  let observations = req.results as? [VNRecognizedTextObservation]
            else {
                result([])
                return
            }

            let blocks: [[String: Any]] = observations.compactMap { obs in
                guard let candidate = obs.topCandidates(1).first else { return nil }
                // Vision uses bottom-left origin; flip Y for Flutter (top-left origin)
                let box = obs.boundingBox
                return [
                    "text":       candidate.string,
                    "confidence": Double(candidate.confidence),
                    "x":          Double(box.origin.x),
                    "y":          Double(1.0 - box.origin.y - box.height),
                    "width":      Double(box.width),
                    "height":     Double(box.height),
                ]
            }
            result(blocks)
        }

        request.recognitionLevel      = .accurate
        request.recognitionLanguages  = ["ja-JP", "en-US"]
        request.usesLanguageCorrection = true
        // Minimum height filter removes noise (letters < 1% of image height)
        request.minimumTextHeight     = 0.01

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                result(FlutterError(code: "OCR_ERROR",
                                    message: error.localizedDescription,
                                    details: nil))
            }
        }
    }

    /// Convert UIImage orientation to CGImagePropertyOrientation for Vision.
    private func cgImagePropertyOrientation(from image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
