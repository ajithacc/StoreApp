//
//  RouteItem.swift
//  StoreMap
//
//  Created by ajith.a.s on 16/06/26.
//

import Foundation
import Mappedin

enum RouteItem {

    case mapObject(MapObject)
    case space(Space)

    var name: String {
        switch self {
        case .mapObject(let object):
            return object.name

        case .space(let space):
            return space.name
        }
    }
}
