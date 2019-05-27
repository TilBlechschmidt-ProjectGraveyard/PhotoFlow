//
//  ImageViewerViewController.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 25.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit

class ImageViewerViewController: UIViewController {
    private let document: ProjectDocument
    private var imageIDs: [ImageEntity.ID]
    private var currentIndex: Int
    private var imageID: ImageEntity.ID {
        return imageIDs[currentIndex]
    }

    private let histogram = ImageHistogram()

    private let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)

    let imageView = UIImageView()

    private lazy var creationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    func navigationBarTitle() -> String {
        var title = ""

        if let entity = document.imageManager.imageEntity(withID: imageID), let filename = entity.originalFilename {
            title = filename
        }

        return title
    }

    init(document: ProjectDocument, imageID: ImageEntity.ID) {
        self.document = document
        self.imageIDs = document.images.map { $0.objectID }
        self.currentIndex = imageIDs.firstIndex(of: imageID) ?? 0 // TODO This is kinda cheated. Do it properly

        super.init(nibName: nil, bundle: nil)

        imageView.alpha = 0
        imageView.contentMode = .scaleAspectFit
        imageView.layer.masksToBounds = true

        loadThumbnail()

        title = navigationBarTitle()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSelf))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(shareImage))

        let dismissGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(dismissSelf))
        dismissGestureRecognizer.direction = .down
        dismissGestureRecognizer.numberOfTouchesRequired = 1
        view.addGestureRecognizer(dismissGestureRecognizer)

        let nextGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(goNext))
        nextGestureRecognizer.direction = .left
        nextGestureRecognizer.numberOfTouchesRequired = 1
        view.addGestureRecognizer(nextGestureRecognizer)

        let previousGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(goPrev))
        previousGestureRecognizer.direction = .right
        previousGestureRecognizer.numberOfTouchesRequired = 1
        view.addGestureRecognizer(previousGestureRecognizer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(imageView)
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        view.addSubview(histogram)
        histogram.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).inset(Constants.uiPadding)
            make.left.equalToSuperview().inset(Constants.uiPadding)
            make.width.equalTo(500)
            make.height.equalTo(250)
        }
    }

    private var sourceFrame: CGRect!
    private var initialID: ImageEntity.ID!

    func beginTransition(from frame: CGRect, completionHandler: (() -> ())? = nil) {
        sourceFrame = frame
        initialID = imageID

        imageView.frame = frame
        imageView.alpha = 1
        imageView.layer.cornerRadius = ShadowedImageView.cornerRadius

        imageView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide.snp.edges)
        }

        UIView.animate(withDuration: 0.15, delay: 0, options: [.layoutSubviews, .curveEaseOut], animations: {
            // TODO Fade in other UI components
            self.imageView.backgroundColor = .black
            self.imageView.layer.cornerRadius = 0
            self.view.backgroundColor = .black
            self.view.layoutIfNeeded()
        }, completion: { _ in
            completionHandler?()
            self.loadOriginalImage()
        })
    }

    @objc func dismissSelf() {
        let isInitialImage = initialID == imageID

        UIView.animate(withDuration: 0.15, delay: 0, options: [.layoutSubviews, .curveEaseOut], animations: {
            // TODO Fade out other UI components
            self.view.backgroundColor = .clear
            self.imageView.backgroundColor = .clear
            self.imageView.layer.cornerRadius = ShadowedImageView.cornerRadius

            if isInitialImage {
                self.imageView.frame = self.sourceFrame
            } else {
                self.imageView.alpha = 0
                self.imageView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            }
        }, completion: { _ in
            self.dismiss(animated: false)
        })
    }

    @objc func goNext() {
        guard let nextIndex = imageIDs.index(from: currentIndex, offset: 1) else {
            // TODO Indicate that no further images are there
            return
        }

        self.currentIndex = nextIndex
        loadOriginalImage() {
            self.title = self.navigationBarTitle()
        }
    }

    @objc func goPrev() {
        guard let previousIndex = imageIDs.index(from: currentIndex, offset: -1) else {
            // TODO Indicate that no further images are there
            return
        }

        self.currentIndex = previousIndex
        loadOriginalImage() {
            self.title = self.navigationBarTitle()
        }
    }

    func loadThumbnail() {
        document.imageManager.fetchImage(withID: imageID, mode: .thumbnail).startWithResult { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    self.imageView.image = image
                case .failure(let error):
                    print(error)
                }
            }
        }
    }

    private var originalImage: UIImage? = nil

    func loadOriginalImage(completionHandler: (() -> ())? = nil) {
        activityIndicator.startAnimating()
        document.imageManager.fetchImage(withID: imageID, mode: .original).startWithResult { result in
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                switch result {
                case .success(let image):
                    self.originalImage = image
                    self.imageView.image = image

                    // TODO Don't calculate on main thread!
                    self.histogram.histogramData = image.cgImage?.calculateNormalizedHistogram()
                case .failure(let error):
                    print(error)
                }
                completionHandler?()
            }
        }
    }

    var shareController: UIDocumentInteractionController?
    @objc func shareImage() {
        document.imageManager.fetchImageData(ofImageWithID: imageID, thumbnail: false).startWithResult { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    let imageEntity = self.document.imageManager.imageEntity(withID: self.imageID)!
                    let url = UIApplication.documentExportCacheDirectory().appendingPathComponent("\(UUID().uuidString).CR2")
                    try! data.write(to: url)
                    self.shareController = UIDocumentInteractionController(url: url)
                    self.shareController?.uti = imageEntity.uti ?? "public.data"
                    self.shareController?.presentOpenInMenu(from: self.navigationItem.rightBarButtonItem!, animated: true)
                }
            case .failure(_):
                return
            }
        }
    }
}
