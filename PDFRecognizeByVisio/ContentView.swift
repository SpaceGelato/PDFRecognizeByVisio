//
//  ContentView.swift
//  PDFRecognizeByVisio
//
//  Created by Roman Vasyliev on 07/09/2023.
//

import SwiftUI
import Vision
import PDFKit
import MobileCoreServices

struct ContentView: View {
    @State private var recognizedStrings: [String] = [] // Holds the recognized text
    @State private var pdfImage: UIImage? // Holds the loaded PDF page image
    @State private var selectedPDFURL: URL? // Holds the selected PDF file URL
    @State private var selectedPage: Int = 1 // Holds the selected page number (default is 1)
    @State private var isDocumentPickerPresented = false // Manages document picker presentation
    @State private var useFilters = false // Flag for using filters

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    if let image = pdfImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width / 2, height: geometry.size.height / 2)
                    } else {
                        Text("Choose a PDF file") // Message when no PDF is selected
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding()
                    }

                    ScrollView {
                        if !recognizedStrings.isEmpty {
                            Text(recognizedStrings.joined(separator: "\n"))
                                .padding()
                                .frame(maxHeight: .infinity) // Expand to maximum height
                        }
                    }
                }
                
                Spacer() // Divider that occupies all available space between blocks
                
                HStack {
                    Button("Choose PDF") {
                        isDocumentPickerPresented.toggle() // Show document picker on button click
                    }
                    .sheet(isPresented: $isDocumentPickerPresented) {
                        DocumentPicker(selectedURL: $selectedPDFURL) // Display document picker
                    }
                    
                    TextField("Page Number", value: $selectedPage, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)

                    HStack {
                        Toggle(isOn: $useFilters) {
                            Text("Use Filters")
                        }
                        .padding()
                        .labelsHidden()
                        
                        Text("Filter")
                    }
            
                    Button("Recognize Text") {
                        if useFilters {
                            recognizeTextWithFilters() // Recognize text with filters
                        } else {
                            recognizeText() // Recognize text without filters
                        }
                    }
                }
                .padding()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TextRecognitionNotification"))) { _ in
            print(self.recognizedStrings)
        }
    }

    // Function to recognize text without filters
    func recognizeText() {
        if let cgImage = getImageFromPDF(withFilters: false) {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage)
            let recognizeTextRequest = VNRecognizeTextRequest { (request, error) in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                DispatchQueue.main.async {
                    self.recognizedStrings = recognizedStrings
                    if let updatedImage = self.applyComicEffect(to: cgImage) {
                        self.pdfImage = UIImage(cgImage: updatedImage)
                    }
                    
                    NotificationCenter.default.post(name: Notification.Name("TextRecognitionNotification"), object: nil)
                }
            }

            recognizeTextRequest.recognitionLevel = .accurate

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try requestHandler.perform([recognizeTextRequest])
                    if let observations = recognizeTextRequest.results {
                        for observation in observations {
                            if let candidates = observation.topCandidates(1).first {
                                print("Recognized text: \(candidates.string)")
                            }
                        }
                    }
                } catch {
                    print(error)
                }
            }
        }
    }

    // Function to recognize text with filters
    func recognizeTextWithFilters() {
        if let cgImage = getImageFromPDF(withFilters: true) {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage)
            let recognizeTextRequest = VNRecognizeTextRequest { (request, error) in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                DispatchQueue.main.async {
                    self.recognizedStrings = recognizedStrings
                    if let updatedImage = self.applyComicEffect(to: cgImage) {
                        self.pdfImage = UIImage(cgImage: updatedImage)
                    }
                    
                    NotificationCenter.default.post(name: Notification.Name("TextRecognitionNotification"), object: nil)
                }
            }

            recognizeTextRequest.recognitionLevel = .accurate

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try requestHandler.perform([recognizeTextRequest])
                    if let observations = recognizeTextRequest.results as? [VNRecognizedTextObservation] {
                        for observation in observations {
                            if let candidates = observation.topCandidates(1).first {
                                print("Recognized text: \(candidates.string)")
                            }
                        }
                    }
                } catch {
                    print(error)
                }
            }
        }
    }

    // Function to get image from PDF with or without filters
    func getImageFromPDF(withFilters useFilters: Bool) -> CGImage? {
        var cgImage: CGImage?

        if let pdfURL = selectedPDFURL,
           let pdfDocument = PDFDocument(url: pdfURL) {

            if let pdfPage = pdfDocument.page(at: selectedPage - 1) {
                if useFilters {
                    return applyComicEffect(to: pdfPage.thumbnail(of: pdfPage.bounds(for: .mediaBox).size, for: .mediaBox).cgImage)
                } else {
                    return pdfPage.thumbnail(of: pdfPage.bounds(for: .artBox).size, for: .artBox).cgImage
                }
            }
        } else {
            print("PDF file not found.")
        }

        return nil
    }

    // Function to apply Lanczos scale transform to an image
    func applyLanczosScaleTransform(to ciImage: CIImage, scale: CGFloat) -> CIImage? {
        if let filter = CIFilter(name: "CILanczosScaleTransform") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(scale, forKey: kCIInputScaleKey)
            filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
            return filter.outputImage
        }
        return nil
    }

    // Function to apply comic effect to an image
    func applyComicEffect(to cgImage: CGImage?) -> CGImage? {
        guard let cgImage = cgImage else {
            return nil
        }
        let ciImage = CIImage(cgImage: cgImage)
        let ciImage2 = applyLanczosScaleTransform(to: ciImage, scale: 3.0)

        if let boxBlurFilter = CIFilter(name: "CIBoxBlur") {
            boxBlurFilter.setValue(ciImage2, forKey: kCIInputImageKey)
            let blurRadius: CGFloat = 2.0
            boxBlurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)

            let ciContext = CIContext(options: nil)
            if let cgImageResult = ciContext.createCGImage(boxBlurFilter.outputImage!, from: boxBlurFilter.outputImage!.extent) {
                return cgImageResult
            }
        }

        return nil
    }
}

// Document Picker for selecting PDF files
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.content"], in: .import)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let selectedURL = urls.first {
                parent.selectedURL = selectedURL
            }
        }
    }
}
