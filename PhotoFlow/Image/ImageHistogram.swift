//
//  ImageHistogram.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 26.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit

//class ImageHistogram: UIView {
//    private let rawImageHistogram = RawImageHistogram()
//
//    var histogramData: NormalizedHistogramBins? {
//        get { return rawImageHistogram.histogramData }
//        set { rawImageHistogram.histogramData = histogramData }
//    }
//
//    var colored: Bool {
//        get { return rawImageHistogram.colored }
//        set { rawImageHistogram.colored = colored }
//    }
//
//    init() {
//        super.init(frame: .zero)
//
//        backgroundColor = Constants.colors.background
//
//        addSubview(rawImageHistogram)
//        rawImageHistogram.snp.makeConstraints { make in
//            make.edges.equalToSuperview().inset(Constants.uiPadding)
//        }
//    }
//
//    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//}

class ImageHistogram: UIView {
    var histogramData: NormalizedHistogramBins? = nil { didSet { self.setNeedsDisplay() } }
    var colored: Bool = true { didSet { self.setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Constants.colors.background
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func draw(_ rect: CGRect) {
        guard let histogramData = histogramData else {
            // TODO Show activity indicator
            return
        }

        // TODO Figure out how to draw lines properly
//        draw(bins: histogramData.red, color: .red, fill: false)
//        draw(bins: histogramData.green, color: .green, fill: false)
//        draw(bins: histogramData.blue, color: .blue, fill: false)

        draw(bins: histogramData.red, color: #colorLiteral(red: 0.7843137255, green: 0.1960784314, blue: 0.1960784314, alpha: 1))
        draw(bins: histogramData.green, color: #colorLiteral(red: 0.1960784314, green: 0.7843137255, blue: 0.1960784314, alpha: 1))
        draw(bins: histogramData.blue, color: #colorLiteral(red: 0.1960784314, green: 0.1960784314, blue: 0.7843137255, alpha: 1))
    }

    private func draw(bins: [CGFloat], color: UIColor, fill: Bool = true) {
        let path = UIBezierPath()

        if colored {
            color.setFill()
            color.setStroke()
        } else {
            UIColor.white.setFill()
        }

        let yAxisHeight = self.bounds.height
        let xAxisWidth = self.bounds.width

        let binCount: CGFloat = 256
        let binWidth = xAxisWidth / binCount

        // Move to origin
        let origin = CGPoint(x: 0, y: yAxisHeight)
        path.move(to: origin)

        // Iterate points
        bins.enumerated().forEach {
            let (offset, value) = $0
            path.addLine(to: CGPoint(x: CGFloat(offset) * binWidth, y: yAxisHeight - value * yAxisHeight))
        }

        if fill {
            path.addLine(to: CGPoint(x: xAxisWidth, y: yAxisHeight))
            path.addLine(to: origin)
            path.fill(with: CGBlendMode.plusLighter, alpha: 1)
        } else {
            // TODO Strokes should only be on the top not behind other areas. Fix it.
            path.stroke()
        }
    }
}
