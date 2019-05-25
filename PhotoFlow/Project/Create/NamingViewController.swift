//
//  NamingViewController.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 21.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit
import SnapKit
import ReactiveCocoa

protocol NamingViewControllerDelegate: class {
    func namingViewControllerDidCancelImport(_ namingViewController: NamingViewController)
    func namingViewController(_ namingViewController: NamingViewController, didSet name: String)
}

class NamingViewController: UIViewController {
    private var inputCenterYConstraint: Constraint!
    private let input = UITextField()

    weak var delegate: NamingViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(animateWithKeyboard(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(animateWithKeyboard(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(nextTapped))

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))

        nameChanged()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.input.becomeFirstResponder()
        }
    }

    override func loadView() {
        super.loadView()

        view = UIView()

        input.placeholder = "Project name"
        input.clearButtonMode = .always
        input.borderStyle = .roundedRect

        input.addTarget(self, action: #selector(nameChanged), for: .editingChanged)

        view.addSubview(input)
        input.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            inputCenterYConstraint = make.centerY.equalToSuperview().constraint
            make.width.equalTo(350)
            make.height.equalTo(50)
        }
    }

    @objc func nameChanged() {
        navigationItem.rightBarButtonItem?.isEnabled = (input.text?.count ?? 0) > 0
    }

    @objc func cancelTapped() {
        delegate?.namingViewControllerDidCancelImport(self)
    }

    @objc func nextTapped() {
        delegate?.namingViewController(self, didSet: input.text ?? "Untitled project")
    }

    @objc func animateWithKeyboard(notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        let keyboardHeight = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height ?? 0
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.5
        let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        let moveUp = (notification.name == UIResponder.keyboardWillShowNotification)

        if moveUp {
            inputCenterYConstraint?.update(offset: -keyboardHeight / 2)
        } else {
            inputCenterYConstraint?.update(offset: 0)
        }

        let options = UIView.AnimationOptions(rawValue: curve << 16)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: options,
            animations: {
                self.view.layoutIfNeeded()
        },
            completion: nil
        )
    }
}
