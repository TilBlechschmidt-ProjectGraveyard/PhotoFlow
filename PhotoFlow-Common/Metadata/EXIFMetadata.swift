//
//  EXIFMetadata.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 21.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

enum ExposureProgram: Int {
    // Manual & Semi-manual programs
    case manual = 1
    case aperturePriority = 3
    case shutterPriority = 4

    // Fully automatic programs
    case autoNormal = 2
    case autoCreative = 5
    case autoAction = 6
    case autoPortrait = 7
    case autoLandscape = 8
}

enum ColorSpace: Int {
    case sRGB = 1
    case adobeRGB = 2
    case uncalibrated = 65535
}

struct EXIFMetadata {
    // Other possibly interesting values: ApertureValue/MaxApertureValue, Flash, FocalPlane*, PixelXDimension, PixelYDimension, MeteringMode

    let digitizationTime: Date?
    let captureTime: Date?

    /// Color space the image was stored in
    let colorSpace: ColorSpace?

    /// Exposure bias value of taking picture. Unit is EV.
    let exposureBias: Double?

    /// Exposure program that the camera used when image was taken.
    let exposureProgram: ExposureProgram?

    /// Shutter speed. To convert this value to ordinary 'Shutter Speed' calculate this value's power of 2, then reciprocal.
    /// For example, if value is '4', shutter speed is 1/(2^4)=1/16 second. NOTE: This value seems to be inaccurate. Use exposure time instead.
    let shutterSpeed: Double?

    /// Exposure time (reciprocal of shutter speed). Unit is second.
    let exposureTime: Double?

    /// The actual F-number (F-stop) of lens when the image was taken.
    let fNumber: Int?

    /// The actual aperture value of lens when the image was taken.
    ///
    /// To convert this value to ordinary F-number(F-stop), calculate this value's power of root 2 (=1.4142).
    /// For example, if value is '5', F-number is 1.4142^5 = F5.6.
    let apertureValue: Double?

    /// Focal length of lens used to take image. Unit is millimeter.
    let focalLength: Int?

    /// CCD sensitivity equivalent to Ag-Hr film speedrate.
    let iso: [Int]?

    /// Human readable exposure
    var exposureString: String? {
        guard let exposureTime = exposureTime else {
            return nil
        }

        if exposureTime < 1 {
            return "1/\(Int(round(1/exposureTime)))"
        } else {
            return "\(exposureTime)"
        }
    }

    /// Human readable aperture
    var apertureString: String? {
        guard let fNumber = fNumber, let fNumberString = apertureFormatter.string(from: NSNumber(value: fNumber)) else {
            return nil
        }

        return "ƒ/\(fNumberString)"
    }

    /// Human readable ISO
    var isoString: String? {
        guard let iso = iso?.first else {
            return nil
        }

        return "ISO \(iso)"
    }

    private var apertureFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2

        return formatter
    }()

    init(from dict: [String: Any]) {
        colorSpace = dict.take(from: "ColorSpace").flatMap { ColorSpace(rawValue: $0) }
        exposureBias = dict.take(from: "ExposureBiasValue")
        exposureProgram = dict.take(from: "ExposureProgram").flatMap { ExposureProgram(rawValue: $0) }
        shutterSpeed = dict.take(from: "ShutterSpeedValue")
        exposureTime = dict.take(from: "ExposureTime")
        fNumber = dict.take(from: "FNumber")
        apertureValue = dict.take(from: "ApertureValue")
        focalLength = dict.take(from: "FocalLength")
        iso = dict.take(from: "ISOSpeedRatings")

        let captureTime: String? = dict.take(from: "DateTimeOriginal")
        let digitizationTime: String? = dict.take(from: "DateTimeDigitized")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"

        self.captureTime = captureTime.flatMap { dateFormatter.date(from: $0) }
        self.digitizationTime = digitizationTime.flatMap { dateFormatter.date(from: $0) }
    }
}
