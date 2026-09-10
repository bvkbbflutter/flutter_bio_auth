import CoreML
import Foundation

/// Passive presentation-attack signal, separate from active-liveness
/// gestures -- see README "Liveness security".
protocol AntiSpoofEngine: AnyObject {
    var isAvailable: Bool { get }
    func analyze(alignedTensor: [Float]) -> AntiSpoofResult
}

final class CoreMLAntiSpoofEngine: AntiSpoofEngine {
    private var model: MLModel?
    var isAvailable: Bool { model != nil }

    init(compiledModelURL: URL?) {
        if let url = compiledModelURL {
            self.model = try? MLModel(contentsOf: url)
        }
    }

    func analyze(alignedTensor: [Float]) -> AntiSpoofResult {
        guard let model = model else { return .unavailable }
        guard let inputName = model.modelDescription.inputDescriptionsByName.keys.first,
              let shape = model.modelDescription.inputDescriptionsByName[inputName]?.multiArrayConstraint?.shape,
              let mlArray = try? MLMultiArray(shape: shape, dataType: .float32) else {
            return AntiSpoofResult(isLive: false, confidence: 0.0, reason: .unknown)
        }
        for (i, value) in alignedTensor.enumerated() where i < mlArray.count {
            mlArray[i] = NSNumber(value: value)
        }

        do {
            let input = try MLDictionaryFeatureProvider(dictionary: [inputName: mlArray])
            let output = try model.prediction(from: input)
            guard let outputName = model.modelDescription.outputDescriptionsByName.keys.first,
                  let outputArray = output.featureValue(for: outputName)?.multiArrayValue,
                  outputArray.count > 0 else {
                return AntiSpoofResult(isLive: false, confidence: 0.0, reason: .unknown)
            }
            let liveProbability = min(1.0, max(0.0, outputArray[0].doubleValue))
            return AntiSpoofResult(
                isLive: liveProbability >= 0.5, confidence: liveProbability,
                reason: liveProbability >= 0.5 ? .live : .suspiciousTexture
            )
        } catch {
            return AntiSpoofResult(isLive: false, confidence: 0.0, reason: .unknown)
        }
    }
}

/// Used when `FaceBiometricConfig.antiSpoofModelAssetPath` is unset.
/// Always reports `.unavailable` -- never a pass -- so callers
/// requiring anti-spoofing fail closed.
final class UnavailableAntiSpoofEngine: AntiSpoofEngine {
    var isAvailable: Bool { false }
    func analyze(alignedTensor: [Float]) -> AntiSpoofResult { .unavailable }
}
