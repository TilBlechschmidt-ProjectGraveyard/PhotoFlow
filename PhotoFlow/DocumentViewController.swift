//
//  DocumentViewController.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 19.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit

class DocumentViewController: UIViewController {
    private let browserVC = ImageBrowserViewController()
    
    var document: ProjectDocument?

    override var navigationItem: UINavigationItem {
        let item = UINavigationItem(title: document?.title ?? "PhotoFlow")
        item.largeTitleDisplayMode = .automatic
        item.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(dismissDocumentViewController))
        return item
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(browserVC)

        view.addSubview(browserVC.view)
        browserVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.backgroundColor = Constants.colors.background

        browserVC.didMove(toParent: self)
        browserVC.view.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.right.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Access the document
        document?.open(completionHandler: { (success) in
            if success {
                // Display the content of the document, e.g.:
                if let document = self.document {
                    self.browserVC.imageManager = document.imageManager
                    self.browserVC.imageEntities = document.imageManager.imageList()
                } else {
                    // TODO Show error / loading indicator
                }
            } else {
                // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
            }
        })
    }
    
    @objc func dismissDocumentViewController() {
        document?.close { closed in
            guard closed else {
                // TODO Tell the user
                print("Failed to close document!")
                return
            }

            self.dismiss(animated: true)
        }
    }
}
