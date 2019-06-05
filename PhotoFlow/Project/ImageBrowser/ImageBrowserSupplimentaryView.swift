//
//  ImageBrowserSupplimentaryView.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 01.06.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit

class ImageBrowserSupplimentaryView: UICollectionReusableView {
    private let titleLabel = UILabel()
    let leftButton = UIButton(type: .system)
    let rightButton = UIButton(type: .system)

    var leftButtonTitle: String! {
        didSet {
            leftButton.setTitle(leftButtonTitle, for: .normal)
        }
    }

    var rightButtonTitle: String! {
        didSet {
            rightButton.setTitle(rightButtonTitle, for: .normal)
        }
    }

    var title: String! {
        didSet {
            titleLabel.text = title
        }
    }

    var leftButtonCallback: (() -> ())?
    var rightButtonCallback: (() -> ())?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        leftButton.setTitle(nil, for: .normal)
        rightButton.setTitle(nil, for: .normal)

        leftButtonCallback = nil
        rightButtonCallback = nil
    }

    func setupUI() {
        blur(style: .dark)

        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)

        let stackView = UIStackView(arrangedSubviews: [leftButton, titleLabel, rightButton])
        stackView.alignment = .center
        stackView.distribution = .equalCentering

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.bottom.equalToSuperview()
            make.right.equalToSuperview().inset(20)
            make.left.equalToSuperview().inset(20)
        }

        leftButton.addTarget(self, action: #selector(leftButtonClicked), for: .touchUpInside)
        rightButton.addTarget(self, action: #selector(rightButtonClicked), for: .touchUpInside)
    }

    @objc func leftButtonClicked() {
        leftButtonCallback?()
    }

    @objc func rightButtonClicked() {
        rightButtonCallback?()
    }
}
