//
//  ImportProgressViewController.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 22.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import Photos

class ImportProgressViewController: UIViewController {
    private let backgroundView = UIImageView()
    private let contentView = UIView()

    private let label = UILabel()
    private let note = UILabel()
    private let imageView = UIImageView()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let activityIndicator = UIActivityIndicatorView(style: .white)
    private let progressLabel = UILabel()
    private let cancelButton = UIButton(type: .system)

    private let importManager: ImportManager

    var onCancel: (() -> ())?

    var totalBytes: Int64 = 0
    var progress: Float = 0 {
        didSet {
            progressBar.progress = progress

            let transferredBytes = Int64(round(Double(totalBytes) * Double(progress)))
            let formatter = ByteCountFormatter()
            let formattedTransferredBytes = formatter.string(fromByteCount: transferredBytes)
            let formattedTotalBytes = formatter.string(fromByteCount: totalBytes)

            progressLabel.text = "\(formattedTransferredBytes) / \(formattedTotalBytes)"
        }
    }

    init(importManager: ImportManager) {
        self.importManager = importManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func loadView() {
        super.loadView()
        view = backgroundView

        label.text = "Importing images"
        note.text = "This may take some time if the images are in the cloud."
        progressLabel.text = "Preparing import ..."

        label.font = label.font.withSize(20)
        note.font = note.font.withSize(13)
        progressLabel.font = progressLabel.font.withSize(13)
        label.textColor = .white
        progressLabel.textColor = .lightGray
        note.textColor = .lightGray

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        backgroundView.isUserInteractionEnabled = true
        backgroundView.contentMode = .scaleAspectFill
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        backgroundView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        contentView.blur(style: .dark)

        let stackView = UIStackView(arrangedSubviews: [label, note, imageView, progressBar, progressLabel, cancelButton])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = Constants.spacing
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        imageView.snp.makeConstraints { make in
            make.width.equalTo(4 * 90)
            make.height.equalTo(3 * 90)
        }

        progressBar.snp.makeConstraints { make in
            make.height.equalTo(2)
            make.width.equalTo(imageView.snp.width)
        }

        activityIndicator.startAnimating()
        imageView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    func load(imageData: Data) {
        if let image = UIImage(data: imageData) {
            imageView.image = image
            backgroundView.image = image
            activityIndicator.stopAnimating()
        }
    }

    @objc func cancel() {
        onCancel?()
    }
}
