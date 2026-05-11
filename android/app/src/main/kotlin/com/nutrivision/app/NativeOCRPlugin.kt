package com.nutrivision.app

import android.graphics.BitmapFactory
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ↔ Android ML Kit bridge.
 *
 * Channel : "com.nutrivision/ocr"
 * Method  : "recognizeText"
 *   Args  : { "imageBytes": ByteArray (JPEG), "rotation": Int (0/90/180/270) }
 *   Returns: List<Map<String, Any>> — text block maps with normalised bounding boxes
 */
class NativeOCRPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.nutrivision/ocr")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "recognizeText") {
            result.notImplemented()
            return
        }

        val imageBytes = call.argument<ByteArray>("imageBytes") ?: run {
            result.error("INVALID_ARGS", "imageBytes is required", null)
            return
        }
        val rotationDeg = call.argument<Int>("rotation") ?: 0

        val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size) ?: run {
            result.error("INVALID_IMAGE", "Cannot decode JPEG", null)
            return
        }

        val inputImage = InputImage.fromBitmap(bitmap, rotationDeg)
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

        recognizer.process(inputImage)
            .addOnSuccessListener { visionText ->
                val w = bitmap.width.toFloat()
                val h = bitmap.height.toFloat()

                val blocks = visionText.textBlocks.flatMap { block ->
                    block.lines.mapNotNull { line ->
                        val box = line.boundingBox ?: return@mapNotNull null
                        mapOf(
                            "text"       to line.text,
                            "confidence" to (line.confidence?.toDouble() ?: 0.85),
                            "x"          to (box.left   / w).toDouble(),
                            "y"          to (box.top    / h).toDouble(),
                            "width"      to (box.width() / w).toDouble(),
                            "height"     to (box.height()/ h).toDouble(),
                        )
                    }
                }
                result.success(blocks)
            }
            .addOnFailureListener { e ->
                result.error("OCR_FAILED", e.message, null)
            }
    }
}
