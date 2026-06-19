//
//  StoreItem.swift
//  StoreMap
//
//  Created by ajith.a.s on 19/06/26.
//

import Foundation
import Foundation

struct StoreItem: Identifiable {

    let id = UUID()

    let name: String
    let imageName: String
    let locationName: String

    var isSelected: Bool = false
}
