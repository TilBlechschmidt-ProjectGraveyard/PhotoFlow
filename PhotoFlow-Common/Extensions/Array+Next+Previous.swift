//
//  Array+Next+Previous.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 26.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

extension Array {
    func index(from index: Int, offset by: Int) -> Int? {
        let newIndex = index + by

        if newIndex >= count || newIndex < 0 {
            return nil
        }

        return newIndex
    }

    func item(after index: Int) -> Element? {
        return self.index(from: index, offset: 1).flatMap { self[$0] }
    }

    func item(before index: Int) -> Element? {
        return self.index(from: index, offset: -1).flatMap { self[$0] }
    }
}
