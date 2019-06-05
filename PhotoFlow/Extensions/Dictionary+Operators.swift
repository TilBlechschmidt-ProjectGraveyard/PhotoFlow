//
//  Dictionary+Operators.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 28.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import Foundation

func += <K, V> (left: inout [K:V], right: [K:V]) {
    for (k, v) in right {
        left[k] = v
    }
}

func + <K, V> (left: [K:V], right: [K:V]) -> [K:V] {
    var result: [K:V] = [:]

    for (k, v) in left {
        result[k] = v
    }

    for (k, v) in right {
        result[k] = v
    }

    return result
}
