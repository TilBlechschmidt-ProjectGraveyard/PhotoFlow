//
//  DocumentViewController.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 19.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit

class DocumentViewController: UIViewController {
    var document: ProjectDocument?

    override var navigationItem: UINavigationItem {
        let item = UINavigationItem(title: document?.title ?? "PhotoFlow")
        item.largeTitleDisplayMode = .automatic
        item.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissVC))
        return item
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    private func loadBrowserVC(with document: ProjectDocument) {
        let browserVC = ImageBrowserViewController(document: document)
        addChild(browserVC)

        view.addSubview(browserVC.view)
        browserVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        browserVC.didMove(toParent: self)
        browserVC.view.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.right.equalToSuperview()
        }

//        browserVC.imageEntities = document.imageManager.imageList()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Constants.colors.background
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Access the document
        if let document = document {
            if document.documentState == .normal {
                self.loadBrowserVC(with: document)
            } else {
                document.open { success in
                    guard success else { return }
                    self.loadBrowserVC(with: document)
                }
            }
        }
        
//        document?.open(completionHandler: { (success) in
//            if success {
//                // Display the content of the document, e.g.:
//                if let document = self.document {
//                    self.loadBrowserVC(with: document)
//                } else {
//                    // TODO Show error / loading indicator
//                }
//            } else {
//                // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
//            }
//        })
    }

    @objc func dismissVC() {
        dismissDocumentViewController()
    }

    func dismissDocumentViewController(completionHandler: (() -> ())? = nil) {
        document?.close { closed in
            guard closed else {
                // TODO Tell the user
                print("Failed to close document!")
                return
            }

            self.dismiss(animated: true, completion: completionHandler)
        }
    }
}
