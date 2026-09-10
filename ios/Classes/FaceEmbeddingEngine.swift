import CoreML
import Foundation

/// Generates a face embedding from an aligned/normalized tensor. An
/// interface (protocol), not a concrete class, so the model is
/// swappable without touching enrollment/authentication logic --
/// mirrors FaceEmbeddingEngine.kt / lib's "Fallback model architecture".
protocol FaceEmbeddingEngine: AnyObject {
    var isAvailable: Bool { get }
    var modelVersion: String { get }
    var embeddingDimension: Int { get }
    func generateEmbedding(alignedTensor: [Float]) throws -> [Float]
}

/// Real implementation: loads a compiled `.mlmodelc` (or a `.tflite`
/// via a bridged TFLite-iOS runtime, if you prefer parity with
/// Android's model format -- swap the loader below) from a Flutter
/// asset path declared in the *consuming app's* `pubspec.yaml`. The
/// plugin itself ships no model bytes.
///
/// Free, permissively-licensed starting points to convert: MediaPipe's
/// Apache-2.0 face models, or a community CoreML/TFLite export of
/// MobileFaceNet / ArcFace-mobile. See README "Model installation".
final class CoreMLFaceEmbeddingEngine: FaceEmbeddingEngine {
    let modelVersion: String
    let embeddingDimension: Int
    private var model: MLModel?

    var isAvailable: Bool { model != nil }

    init(compiledModelURL: URL?, modelVersion: String, embeddingDimension: Int) {
        self.modelVersion = modelVersion
        self.embeddingDimension = embeddingDimension
        if let url = compiledModelURL {
            self.model = try? MLModel(contentsOf: url)
        }
    }

    func generateEmbedding(alignedTensor: [Float]) throws -> [Float] {
        guard let model = model else {
            throw BiometricException(
                .modelUnavailable,
                "No embedding model loaded. Configure FaceBiometricConfig.embeddingModelAssetPath " +
                "with a valid asset path to a compiled face-embedding model."
            )
        }

        guard let inputDescription = model.modelDescription.inputDescriptionsByName.values.first,
              let inputName = model.modelDescription.inputDescriptionsByName.keys.first,
              let shapeConstraint = inputDescription.multiArrayConstraint?.shape else {
            throw BiometricException(.embeddingGenerationFailed, "Embedding model has an unexpected input signature.")
        }

        guard let mlArray = try? MLMultiArray(shape: shapeConstraint, dataType: .float32) else {
            throw BiometricException(.embeddingGenerationFailed, "Failed to allocate the model input tensor.")
        }
        for (i, value) in alignedTensor.enumerated() where i < mlArray.count {
            mlArray[i] = NSNumber(value: value)
        }

        do {
            let input = try MLDictionaryFeatureProvider(dictionary: [inputName: mlArray])
            let output = try model.prediction(from: input)
            guard let outputName = model.modelDescription.outputDescriptionsByName.keys.first,
                  let outputArray = output.featureValue(for: outputName)?.multiArrayValue else {
                throw BiometricException(.embeddingGenerationFailed, "Embedding model produced no usable output.")
            }
            var raw = [Float](repeating: 0, count: outputArray.count)
            for i in 0..<outputArray.count { raw[i] = outputArray[i].floatValue }

            guard raw.count == embeddingDimension, raw.allSatisfy({ $0.isFinite }) else {
                throw BiometricException(
                    .embeddingGenerationFailed,
                    "Embedding model produced an invalid output vector " +
                    "(expected dimension \(embeddingDimension), got \(raw.count))."
                )
            }
            return l2Normalize(raw)
        } catch let error as BiometricException {
            throw error
        } catch {
            throw BiometricException(.embeddingGenerationFailed, "The embedding model failed to run.", underlying: error)
        }
    }

    private func l2Normalize(_ v: [Float]) -> [Float] {
        let sumSq = v.reduce(0.0) { $0 + Double($1) * Double($1) }
        let norm = sqrt(sumSq)
        guard norm != 0 else { return v }
        return v.map { Float(Double($0) / norm) }
    }
}

/// Used when `FaceBiometricConfig.embeddingModelAssetPath` is unset.
/// Never returns a real-looking embedding -- makes
/// detection/tracking/liveness demoable with zero AI models while
/// enroll()/authenticate()/compare() fail closed instead of faking a
/// result.
final class UnavailableFaceEmbeddingEngine: FaceEmbeddingEngine {
    let modelVersion: String
    let embeddingDimension: Int
    var isAvailable: Bool { false }

    init(modelVersion: String = "none", embeddingDimension: Int = 0) {
        self.modelVersion = modelVersion
        self.embeddingDimension = embeddingDimension
    }

    func generateEmbedding(alignedTensor: [Float]) throws -> [Float] {
        throw BiometricException(
            .modelUnavailable,
            "No embedding model configured. Face recognition, enroll(), authenticate(), and " +
            "compare() are unavailable until FaceBiometricConfig.embeddingModelAssetPath is set. " +
            "Detection, tracking, quality, and active liveness still work."
        )
    }
}
