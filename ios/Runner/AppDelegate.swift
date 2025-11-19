import Flutter
import UIKit
import VisionKit

@main
@objc class AppDelegate: FlutterAppDelegate, VNDocumentCameraViewControllerDelegate {
  private var scanResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "writescan/vision_scanner",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self, weak controller] call, result in
        guard let self = self, let controller = controller else {
          result(FlutterError(code: "unavailable", message: "Controller missing", details: nil))
          return
        }
        switch call.method {
        case "scanDocument":
          self.presentVisionScanner(from: controller, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func presentVisionScanner(from controller: UIViewController, result: @escaping FlutterResult) {
    guard VNDocumentCameraViewController.isSupported else {
      result(FlutterError(code: "vision_unavailable", message: "Document scanner unavailable", details: nil))
      return
    }
    let scanner = VNDocumentCameraViewController()
    scanner.delegate = self
    scanResult = result
    controller.present(scanner, animated: true, completion: nil)
  }

  public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    let fileURL = saveScan(scan)
    controller.dismiss(animated: true) {
      if let path = fileURL?.path {
        self.scanResult?(path)
      } else {
        self.scanResult?(FlutterError(code: "save_failed", message: "Unable to save document", details: nil))
      }
      self.scanResult = nil
    }
  }

  public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true) {
      self.scanResult?(FlutterError(code: "cancelled", message: "User cancelled", details: nil))
      self.scanResult = nil
    }
  }

  public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
    controller.dismiss(animated: true) {
      self.scanResult?(FlutterError(code: "scan_failed", message: error.localizedDescription, details: nil))
      self.scanResult = nil
    }
  }

  private func saveScan(_ scan: VNDocumentCameraScan) -> URL? {
    guard scan.pageCount > 0 else { return nil }
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("scan-\(UUID().uuidString).pdf")

    UIGraphicsBeginPDFContextToFile(fileURL.path, .zero, nil)
    for index in 0 ..< scan.pageCount {
      let image = scan.imageOfPage(at: index)
      let bounds = CGRect(origin: .zero, size: image.size)
      UIGraphicsBeginPDFPageWithInfo(bounds, nil)
      image.draw(in: bounds)
    }
    UIGraphicsEndPDFContext()

    return fileURL
  }
}
