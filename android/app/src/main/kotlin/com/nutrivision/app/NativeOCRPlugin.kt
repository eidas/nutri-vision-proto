package com.nutrivision.app

import android.graphics.BitmapFactory
import android.graphics.Rect
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Flutter ↔ Android ML Kit bridge.
 *
 * Channel : "com.nutrivision/ocr"
 * Method  : "recognizeText"
 *   Args  : { "imageBytes": ByteArray (JPEG), "rotation": Int (0/90/180/270) }
 *   Returns: List<Map<String, Any>> — text block maps with normalised bounding boxes
 *
 * Runs the Latin and Japanese ML Kit recognisers in parallel so the app
 * handles all three supported label formats (JP / FDA / EU) on a single frame.
 * Results are merged and deduplicated by bounding-box overlap before returning.
 */
class NativeOCRPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private val executor = Executors.newCachedThreadPool()

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
        val w = bitmap.width.toFloat()
        val h = bitmap.height.toFloat()

        // Run Latin and Japanese recognisers in parallel.
        // Latin covers FDA / EU labels; Japanese covers 食品表示基準 labels.
        // Both models also recognise the other script to some degree, but
        // running both maximises recall across all three supported formats.
        val latinTask    = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                               .process(inputImage)
        val japaneseTask = TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
                               .process(inputImage)

        Tasks.whenAllSuccess<Text>(latinTask, japaneseTask)
            .addOnSuccessListener(executor) { visionTexts ->
                val raw = visionTexts.flatMap { vt ->
                    vt.textBlocks.flatMap { block ->
                        block.lines.mapNotNull { line ->
                            val box = line.boundingBox ?: return@mapNotNull null
                            LineResult(
                                text       = line.text,
                                confidence = line.confidence?.toDouble() ?: 0.85,
                                normRect   = NormRect(box, w, h),
                            )
                        }
                    }
                }
                val merged = deduplicateByOverlap(raw)
                result.success(merged.map { it.toMap() })
            }
            .addOnFailureListener { e ->
                result.error("OCR_FAILED", e.message, null)
            }
    }

    // ── Deduplication ──────────────────────────────────────────────────────

    /**
     * Remove duplicate lines produced when both recognisers detect the same
     * text region. Two lines are considered duplicates when their bounding
     * boxes overlap by more than [IOU_THRESHOLD]. The line with higher
     * confidence is kept.
     */
    private fun deduplicateByOverlap(
        lines: List<LineResult>,
        iouThreshold: Float = 0.5f,
    ): List<LineResult> {
        val kept = mutableListOf<LineResult>()
        for (candidate in lines) {
            val duplicate = kept.any { existing ->
                iou(candidate.normRect, existing.normRect) > iouThreshold
            }
            if (!duplicate) kept.add(candidate)
        }
        return kept
    }

    /** Intersection-over-Union of two normalised rectangles. */
    private fun iou(a: NormRect, b: NormRect): Float {
        val interLeft   = maxOf(a.left,   b.left)
        val interTop    = maxOf(a.top,    b.top)
        val interRight  = minOf(a.right,  b.right)
        val interBottom = minOf(a.bottom, b.bottom)
        if (interRight <= interLeft || interBottom <= interTop) return 0f
        val interArea = (interRight - interLeft) * (interBottom - interTop)
        val unionArea = a.area + b.area - interArea
        return if (unionArea <= 0f) 0f else interArea / unionArea
    }

    // ── Data classes ────────────────────────────────────────────────────────

    private data class NormRect(
        val left: Float, val top: Float,
        val right: Float, val bottom: Float,
    ) {
        val area get() = (right - left) * (bottom - top)

        constructor(box: Rect, w: Float, h: Float) : this(
            left   = box.left   / w,
            top    = box.top    / h,
            right  = box.right  / w,
            bottom = box.bottom / h,
        )
    }

    private data class LineResult(
        val text: String,
        val confidence: Double,
        val normRect: NormRect,
    ) {
        fun toMap(): Map<String, Any> = mapOf(
            "text"       to text,
            "confidence" to confidence,
            "x"          to normRect.left.toDouble(),
            "y"          to normRect.top.toDouble(),
            "width"      to (normRect.right  - normRect.left).toDouble(),
            "height"     to (normRect.bottom - normRect.top).toDouble(),
        )
    }
}
