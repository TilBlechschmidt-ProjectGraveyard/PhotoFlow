//
//  ImageMetadataView.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 27.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import MapKit
import ReactiveSwift

class ImageMetadataView: UIView {
    private let placeholder = "———"

    private var disposable: Disposable? = nil
    private let browsingManager: BrowsingManager
    private let imageManager: ImageManager

    private let verticalStackView = UIStackView()

    var index: Int? {
        didSet {
            loadMetadata()
        }
    }

    init(imageManager: ImageManager, browsingManager: BrowsingManager, index: Int) {
        self.imageManager = imageManager
        self.browsingManager = browsingManager
        self.index = index

        super.init(frame: .zero)

        setupUI()
        loadMetadata()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Settings
    let shutterSpeedLabel = UILabel()
    let apertureLabel = UILabel()
    let isoLabel = UILabel()
    let focalLengthLabel = UILabel()

    // Gear
    let cameraMakeLabel = UILabel()
    let cameraModelLabel = UILabel()
    let lensLabel = UILabel()
    let exposureProgramLabel = UILabel()

    // File
    let sizeLabel = UILabel()
    let fileTypeLabel = UILabel()
    let resolutionLabel = UILabel()

    // Other meta
    let copyrightLabel = UILabel()

    // Location
    let mapView = MKMapView()
    let annotation = MKPointAnnotation()

    private func setupUI() {
        verticalStackView.alignment = .center
        verticalStackView.axis = .vertical
        verticalStackView.spacing = Constants.spacing * 2

        // Settings
        setup(label: shutterSpeedLabel)
        setup(label: apertureLabel)
        setup(label: isoLabel)
        setup(label: focalLengthLabel)

        let topInformationStackView = UIStackView(arrangedSubviews: [
            shutterSpeedLabel,
            apertureLabel,
            isoLabel,
            focalLengthLabel
        ])
        topInformationStackView.distribution = .equalSpacing
        verticalStackView.addArrangedSubview(topInformationStackView)
        topInformationStackView.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(Constants.spacing * 4)
            make.right.equalToSuperview().inset(Constants.spacing * 4)
        }

        addSpacer()

        // Gear
        add(label: cameraMakeLabel, title: "Make")
        add(label: cameraModelLabel, title: "Model")
        add(label: lensLabel, title: "Lens")
        add(label: exposureProgramLabel, title: "Mode")
        addSpacer()

        // File
        add(label: sizeLabel, title: "Size")
        add(label: fileTypeLabel, title: "Format")
        add(label: resolutionLabel, title: "Resolution")
        addSpacer()

        // Other
        add(label: copyrightLabel, title: "Copyright")
        addSpacer()

        verticalStackView.setContentHuggingPriority(.required, for: .vertical)
        verticalStackView.setContentCompressionResistancePriority(.required, for: .vertical)
        addSubview(verticalStackView)
        verticalStackView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.top.equalToSuperview().inset(Constants.spacing * 2)
        }

        mapView.setContentHuggingPriority(.defaultLow, for: .vertical)
        mapView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        mapView.centerCoordinate = CLLocationCoordinate2D(latitude: 51.1, longitude: 10.2)
        addSubview(mapView)
        mapView.snp.makeConstraints { make in
            make.top.equalTo(verticalStackView.snp.bottom)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    private func add(label: UILabel, title: String) {
        let rowView = UIView()
        verticalStackView.addArrangedSubview(rowView)
        rowView.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }

        let titleLabel = UILabel()
        titleLabel.text = title

        titleLabel.textColor = .lightGray
        label.textColor = .white

        titleLabel.textAlignment = .right
        label.textAlignment = .left

        titleLabel.font = UIFont.systemFont(ofSize: 12)
        label.font = UIFont.systemFont(ofSize: 14)

        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping

        rowView.addSubview(titleLabel)
        rowView.addSubview(label)

        titleLabel.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.25)
        }

        label.snp.makeConstraints { make in
            make.left.equalTo(titleLabel.snp.right).inset(-Constants.spacing * 2)
            make.right.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    private func addSpacer() {
        let spacer = UIView()
        spacer.backgroundColor = Constants.colors.border
        verticalStackView.addArrangedSubview(spacer)
        spacer.snp.makeConstraints { make in
            make.height.equalTo(1)
            make.width.equalToSuperview()
        }
    }

    private func setup(label: UILabel) {
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
    }

    private func resetLabels() {
        let labels = [
            shutterSpeedLabel,
            apertureLabel,
            isoLabel,
            focalLengthLabel,
            cameraMakeLabel,
            cameraModelLabel,
            lensLabel,
            exposureProgramLabel,
            sizeLabel,
            fileTypeLabel,
            resolutionLabel,
            copyrightLabel
        ]

        labels.forEach { $0.text = placeholder }
    }

    private func loadMetadata() {
        disposable?.dispose()
        resetLabels()
        mapView.removeAnnotation(annotation)

        guard let index = index, let entity = imageManager.imageEntity(withID: browsingManager[index]) else {
            return
        }

        DispatchQueue.main.async {
            // File
            self.fileTypeLabel.text = entity.humanReadableUTI ?? self.placeholder
            self.resolutionLabel.text = "\(entity.width) x \(entity.height)"
            self.sizeLabel.text = ByteCountFormatter().string(fromByteCount: entity.filesize)
        }

        disposable = imageManager.fetchMetadata(ofImageWithID: browsingManager[index]).startWithResult { result in
            DispatchQueue.main.async {
                guard let metadata = result.value else {
                    return
                }

                if let exif = metadata.exif {
                    // Settings
                    self.shutterSpeedLabel.text = exif.exposureString ?? self.placeholder
                    self.apertureLabel.text = exif.apertureString ?? self.placeholder
                    self.isoLabel.text = exif.isoString ?? self.placeholder
                    self.focalLengthLabel.text = exif.focalLength.flatMap { "\($0)mm" } ?? self.placeholder

                    // Gear
                    self.exposureProgramLabel.text = exif.exposureProgramString ?? self.placeholder
                }

                if let aux = metadata.aux {
                    // Gear
                    self.lensLabel.text = aux.lensModel ?? self.placeholder
                }

                if let tiff = metadata.tiff {
                    // Gear
                    self.cameraMakeLabel.text = tiff.make ?? self.placeholder
                    self.cameraModelLabel.text = tiff.model ?? self.placeholder

                    // Other
                    self.copyrightLabel.text = tiff.copyright ?? self.placeholder
                }

                if let location = metadata.location {
                    self.annotation.coordinate = location
                    self.mapView.addAnnotation(self.annotation)
                    self.mapView.setCenter(location, animated: true)
                }
            }
        }
    }
}
