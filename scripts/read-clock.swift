import AppKit
import Vision

// Reads the status-bar clock out of each watch screenshot passed as an argument.
for path in CommandLine.arguments.dropFirst() {
    guard let image = NSImage(contentsOfFile: path),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("?? \(path)")
        continue
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // Status bar only: top 18% of the frame.
    request.regionOfInterest = CGRect(x: 0.4, y: 0.82, width: 0.6, height: 0.18)

    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try? handler.perform([request])
    let text = (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: " ")
    print("\(text.isEmpty ? "(none)" : text)\t\(path)")
}
