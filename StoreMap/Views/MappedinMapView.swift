//
//  MappedinMapView.swift
//  StoreMap
//
//  Created by ajith.a.s on 16/06/26.
//

import Foundation
import SwiftUI
import Mappedin

struct MappedinMapView: UIViewRepresentable {

    let mapView: MapView

    func makeUIView(context: Context) -> UIView {

        let container = UIView()

        let webView = mapView.view

        webView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(
                equalTo: container.leadingAnchor
            ),
            webView.trailingAnchor.constraint(
                equalTo: container.trailingAnchor
            ),
            webView.topAnchor.constraint(
                equalTo: container.topAnchor
            ),
            webView.bottomAnchor.constraint(
                equalTo: container.bottomAnchor
            )
        ])

        return container
    }

    func updateUIView(
        _ uiView: UIView,
        context: Context
    ) {

    }
}
