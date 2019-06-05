//
//  ImageViewerViewController.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 25.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import SnapKit

class ImageViewerViewController: UIViewController {
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override var prefersStatusBarHidden: Bool {
        return fullscreen
    }

    private var rawCache: [Int: UIImage] = [:]

    private let imageManager: ImageManager
    private let statusManager: ImageStatusManager
    private let browsingManager: BrowsingManager

    private var index: Int {
        didSet {
            self.histogram.histogramData = nil
            self.metadataView.index = index

            if let cachedImage = rawCache[index] {
                show(image: cachedImage, isRaw: true)
                self.title = self.navigationBarTitle()
                updateCollectionViewSelection()
            } else {
                loadOriginalImage() {
                    self.title = self.navigationBarTitle()
                    self.updateCollectionViewSelection()
                }
            }

            // Clear and repopulate the cache
            repopulateCache()
        }
    }

    private let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)

    let imageView = UIImageView()

    private var translation: CGPoint = .zero
    private var scale: CGFloat = 1
    private var initialScale: CGFloat = 1

    private let acceptedIcon = UIImageView(image: #imageLiteral(resourceName: "CheckMark"))
    private let rejectedIcon = UIImageView(image: #imageLiteral(resourceName: "Rejected"))

    private var rightPanelAnchor: Constraint!
    private let rightPanelView = UIView()
    private let histogram = ImageHistogram()
    private let metadataView: ImageMetadataView

    private let horizontalImageBrowser: HorizontalImageBrowserViewController

    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var pinchGestureRecognizer: UIPinchGestureRecognizer!

    private var nextTimer: Timer?

    private var auxiliaryViews: [UIView]

    private lazy var creationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    func navigationBarTitle() -> String {
        let entity = imageManager.imageEntity(withID: browsingManager[index])
        return entity?.originalFilename ?? ""
    }

    init(imageManager: ImageManager, statusManager: ImageStatusManager, browsingManager: BrowsingManager, index: Int) {
        self.imageManager = imageManager
        self.statusManager = statusManager
        self.browsingManager = browsingManager
        self.index = index
        self.horizontalImageBrowser = HorizontalImageBrowserViewController(imageManager: imageManager, browsingManager: browsingManager)
        self.metadataView = ImageMetadataView(imageManager: imageManager, browsingManager: browsingManager, index: index)
        self.auxiliaryViews = [rightPanelView, horizontalImageBrowser.view]

        self.rightPanelShown = ImageViewerSettings.get(setting: .infoPanelShown) as? Bool ?? true

        super.init(nibName: nil, bundle: nil)

        imageView.alpha = 0
        imageView.contentMode = .scaleAspectFit
        imageView.layer.masksToBounds = true

        horizontalImageBrowser.delegate = self

        loadThumbnail()

        title = navigationBarTitle()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSelf))

        let rightBarButtonItems: [UIBarButtonItem] = [
            UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(shareImage)),
            UIBarButtonItem(title: "Info", style: .plain, target: self, action: #selector(toggleInfo))
        ]

        navigationItem.rightBarButtonItems = rightBarButtonItems

        let nextGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(goNext))
        nextGestureRecognizer.direction = .left
        nextGestureRecognizer.numberOfTouchesRequired = 1
        imageView.addGestureRecognizer(nextGestureRecognizer)

        let previousGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(goPrev))
        previousGestureRecognizer.direction = .right
        previousGestureRecognizer.numberOfTouchesRequired = 1
        imageView.addGestureRecognizer(previousGestureRecognizer)

        let dismissGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(dismissSelf))
        dismissGestureRecognizer.direction = .down
        dismissGestureRecognizer.numberOfTouchesRequired = 1
        imageView.addGestureRecognizer(dismissGestureRecognizer)

        let rejectGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(rejectImage))
        rejectGestureRecognizer.numberOfTapsRequired = 2
        rejectGestureRecognizer.numberOfTouchesRequired = 1
        imageView.addGestureRecognizer(rejectGestureRecognizer)

        let acceptGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(acceptImage))
        acceptGestureRecognizer.numberOfTapsRequired = 1
        acceptGestureRecognizer.numberOfTouchesRequired = 1
        imageView.addGestureRecognizer(acceptGestureRecognizer)

        let fullscreenGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleFullscreen))
        fullscreenGestureRecognizer.numberOfTapsRequired = 2
        fullscreenGestureRecognizer.numberOfTouchesRequired = 2
        imageView.addGestureRecognizer(fullscreenGestureRecognizer)

        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(userPinched))
        pinchGestureRecognizer.delegate = self
        imageView.addGestureRecognizer(pinchGestureRecognizer)

        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(userPanned))
        panGestureRecognizer.minimumNumberOfTouches = 2
        panGestureRecognizer.delegate = self
        imageView.addGestureRecognizer(panGestureRecognizer)

        repopulateCache()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isImportedImage: Bool {
        return imageManager.imageEntity(withID: browsingManager[index]) as? ImportedImageEntity != nil
    }

    @objc func acceptImage() {
        guard isImportedImage else {
            return
        }

        statusManager.flag(image: browsingManager[index], as: .accepted, toggle: true)
        acceptedIcon.alpha = 1

        UIView.animate(withDuration: 0.5) {
            self.acceptedIcon.alpha = 0
        }

        nextTimeout()
    }

    @objc func rejectImage() {
        guard isImportedImage else {
            return
        }

        statusManager.flag(image: browsingManager[index], as: .rejected, toggle: true)
        rejectedIcon.alpha = 1

        UIView.animate(withDuration: 0.5) {
            self.rejectedIcon.alpha = 0
        }

        nextTimeout()
    }

    func nextTimeout() {
        guard ImageViewerSettings.get(setting: .nextOnFlag) as? Bool ?? false else {
            return
        }

        if let nextTimer = nextTimer {
            nextTimer.invalidate()
        }

        nextTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.goNext()
        }
    }

    @objc func userPanned(recognizer: UIPanGestureRecognizer) {
        translation.x += recognizer.translation(in: imageView).x
        translation.y += recognizer.translation(in: imageView).y
        recognizer.setTranslation(.zero, in: imageView)

        updateImageTransform()
    }

    @objc func userPinched(recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began {
            initialScale = scale
            recognizer.scale = scale
        }

        scale = recognizer.scale

        if recognizer.state == .ended && scale < 1 {
            if initialScale == 1 && scale < 0.5 {
                DispatchQueue.main.async {
                    self.dismissSelf()
                }
            } else {
                scale = 1.0
                translation = .zero
                updateImageTransform(animated: true)
            }
        } else {
            updateImageTransform()
        }
    }

    func updateImageTransform(animated: Bool = false) {
        let transform = CGAffineTransform.identity
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: translation.x, y: translation.y)

        if animated {
            UIView.animate(withDuration: 0.25) {
                self.imageView.transform = transform
            }
        } else {
            imageView.transform = transform
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        acceptedIcon.tintColor = Constants.colors.accepted
        rejectedIcon.tintColor = Constants.colors.rejected

        acceptedIcon.alpha = 0
        rejectedIcon.alpha = 0

        view.addSubview(imageView)
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalTo(imageView)
        }

        rightPanelView.blur(style: .dark)
        view.addSubview(rightPanelView)
        rightPanelView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            rightPanelAnchor = make.right.equalToSuperview().offset(rightPanelShown ? 0 : 350).constraint
            make.bottom.equalToSuperview()
            make.width.equalTo(350)
        }

        rightPanelView.addSubview(histogram)
        histogram.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.height.equalTo(200)
        }

        rightPanelView.addSubview(metadataView)
        metadataView.snp.makeConstraints { make in
            make.top.equalTo(histogram.snp.bottom)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        addChild(horizontalImageBrowser)
        view.addSubview(horizontalImageBrowser.view)
        horizontalImageBrowser.view.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.equalToSuperview()
            make.right.equalTo(rightPanelView.snp.left)
            make.height.equalTo(75)
        }
        horizontalImageBrowser.didMove(toParent: self)

        view.addSubview(acceptedIcon)
        acceptedIcon.snp.makeConstraints { make in
            make.center.equalTo(imageView)
            make.width.equalTo(50)
            make.height.equalTo(50)
        }
        view.addSubview(rejectedIcon)
        rejectedIcon.snp.makeConstraints { make in
            make.center.equalTo(imageView)
            make.width.equalTo(50)
            make.height.equalTo(50)
        }

        imageView.isUserInteractionEnabled = true
    }

    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.navigationBar.alpha = 0
    }

    private var sourceFrame: CGRect!
    private var initialIndex: Int!

    private var imageViewTopAgainstBrowserConstraint: Constraint!
    private var imageViewTopFlushConstraint: Constraint!

    func beginTransition(from frame: CGRect, completionHandler: (() -> ())? = nil) {
        sourceFrame = frame
        initialIndex = index

        imageView.frame = frame
        imageView.alpha = 1
        imageView.layer.cornerRadius = ShadowedImageView.cornerRadius

        imageView.snp.makeConstraints { make in
            imageViewTopAgainstBrowserConstraint = make.top.equalTo(horizontalImageBrowser.view.snp.bottom).constraint
            make.bottom.equalToSuperview()
            make.left.equalTo(view.safeAreaLayoutGuide)
            make.right.equalTo(rightPanelView.snp.left)
        }

        imageView.snp.prepareConstraints { make in
            imageViewTopFlushConstraint = make.top.equalToSuperview().constraint
        }

        UIView.animate(withDuration: 0.15, delay: 0, options: [.layoutSubviews, .curveEaseOut], animations: {
            self.imageView.backgroundColor = .black
            self.imageView.layer.cornerRadius = 0
            self.view.backgroundColor = .black
            self.view.layoutIfNeeded()

            self.navigationController?.navigationBar.alpha = 1
            self.auxiliaryViews.forEach { $0.alpha = 1 }
        }, completion: { _ in
            completionHandler?()
            self.loadOriginalImage()
            self.updateCollectionViewSelection(animated: false)
        })
    }

    private var rightPanelWasPreviouslyShown = false
    private var fullscreen: Bool = false {
        didSet {
            if fullscreen {
                rightPanelWasPreviouslyShown = rightPanelShown
                rightPanelShown = false
                horizontalImageBrowser.view.alpha = 0
                navigationController?.setNavigationBarHidden(true, animated: true)

                imageViewTopAgainstBrowserConstraint.deactivate()
                imageViewTopFlushConstraint.activate()
            } else {
                rightPanelShown = rightPanelWasPreviouslyShown
                horizontalImageBrowser.view.alpha = 1
                navigationController?.setNavigationBarHidden(false, animated: true)

                imageViewTopFlushConstraint.deactivate()
                imageViewTopAgainstBrowserConstraint.activate()
            }

            UIView.animate(withDuration: 0.25) {
                self.setNeedsStatusBarAppearanceUpdate()
                self.setNeedsUpdateOfHomeIndicatorAutoHidden()
                self.view.layoutIfNeeded()
            }
        }
    }

    private var rightPanelShown: Bool {
        didSet {
            rightPanelAnchor.update(offset: rightPanelShown ? 0 : 350)
            ImageViewerSettings.set(setting: .infoPanelShown, rightPanelShown)

            UIView.animate(withDuration: 0.25) {
                self.view.layoutIfNeeded()
            }
        }
    }

    @objc func toggleFullscreen() {
        fullscreen = !fullscreen
    }

    @objc func toggleInfo() {
        rightPanelShown = !rightPanelShown
    }

    @objc func dismissSelf() {
        let isInitialImage = initialIndex == index

        view.layoutIfNeeded()

        UIView.animate(withDuration: 0.15, delay: 0, options: [.layoutSubviews, .curveEaseOut], animations: {
            self.view.backgroundColor = .clear
            self.imageView.backgroundColor = .clear
            self.imageView.layer.cornerRadius = ShadowedImageView.cornerRadius

            if isInitialImage {
                self.imageView.frame = self.sourceFrame
            } else {
                self.imageView.alpha = 0
                self.imageView.transform = self.imageView.transform.scaledBy(x: 0.1, y: 0.1)
            }

            self.navigationController?.navigationBar.alpha = 0
            self.auxiliaryViews.forEach { $0.alpha = 0 }
        }, completion: { _ in
            self.dismiss(animated: false)
        })
    }

    @objc func goNext() {
        guard let nextIndex = browsingManager.index(after: index) else {
            // TODO Indicate that no further images are there
            return
        }

        self.index = nextIndex
    }

    @objc func goPrev() {
        guard let previousIndex = browsingManager.index(before: index) else {
            // TODO Indicate that no further images are there
            return
        }

        self.index = previousIndex
    }

    private func updateCollectionViewSelection(animated: Bool = true) {
        horizontalImageBrowser.collectionView.selectItem(at: IndexPath(item: index, section: 0), animated: animated, scrollPosition: .centeredHorizontally)
    }

    private func repopulateCache() {
        // TODO Only clear the parts that are no longer needed (50% in most cases)
        rawCache = [:]
        browsingManager.index(before: index).flatMap { cacheImage(at: $0) }
        browsingManager.index(after: index).flatMap { cacheImage(at: $0) }
    }

    private func loadThumbnail() {
        let id = browsingManager[index]
        imageManager.fetchImage(withID: id, mode: .thumbnail).startWithResult { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    self.show(image: image)
                case .failure(let error):
                    print(error)
                }
            }
        }
    }

    private func loadOriginalImage(completionHandler: (() -> ())? = nil) {
        activityIndicator.startAnimating()
        let id = browsingManager[index]
        imageManager.fetchImage(withID: id, mode: .original).startWithResult { result in
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                switch result {
                case .success(let image):
                    self.show(image: image, isRaw: true)
                case .failure(let error):
                    print(error)
                }
                completionHandler?()
            }
        }
    }

    private func show(image: UIImage, isRaw: Bool = false) {
        self.imageView.image = image
        self.imageView.alpha = 1

        if isRaw {
            self.histogram.histogramData = image.cgImage?.calculateNormalizedHistogram()
        }
    }

    private func cacheImage(at index: Int) {
        let id = browsingManager[index]
        imageManager.fetchImage(withID: id, mode: .original).startWithResult { result in
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                switch result {
                case .success(let image):
                    self.rawCache[index] = image
                case .failure(let error):
                    print(error)
                }
            }
        }
    }

    private let shareManager = ShareManager()
    private var shareController: UIDocumentInteractionController?
    @objc func shareImage() {
        // TODO Export for edited images. Should also change the navbar item to the share button.
        guard isImportedImage else {
            return
        }

        let id = browsingManager[index]
        let projectLocation = imageManager.projectLocation
        guard let filename = shareManager.generateOutgoingFilename(forProjectAt: projectLocation, imageID: id) else {
            return
        }

        // TODO Show loading indicator since the fetching & writing might take some time.
        imageManager.fetchImageData(ofImageWithID: id, thumbnail: false).startWithResult { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    let entity = self.imageManager.imageEntity(withID: self.browsingManager[self.index])
                    let uti = entity?.uti ?? "public.data"
                    let fileExtension = self.shareManager.fileExtension(for: uti) ?? ".jpg"

                    let url = UIApplication.documentExportCacheDirectory().appendingPathComponent("\(filename).\(fileExtension)")

                    try! data.write(to: url)

                    self.shareController = UIDocumentInteractionController(url: url)
                    self.shareController?.uti = uti
                    self.shareController?.presentOpenInMenu(from: self.navigationItem.rightBarButtonItem!, animated: true)
                }
            case .failure(_):
                return
            }
        }
    }
}

extension ImageViewerViewController: HorizontalImageBrowserViewControllerDelegate {
    func horizontalImageBrowserViewController(_ horizontalImageBrowserViewController: HorizontalImageBrowserViewController, didSelectItemAt index: Int) {
        self.index = index
    }
}

extension ImageViewerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer == pinchGestureRecognizer && otherGestureRecognizer == panGestureRecognizer
            || gestureRecognizer == panGestureRecognizer && otherGestureRecognizer == pinchGestureRecognizer
    }
}
