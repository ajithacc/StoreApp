//
//  MapScreen.swift
//  StoreMap
//
//  Created by ajith.a.s on 16/06/26.
//

import Foundation
import SwiftUI

struct StoreDetailsSheet: View {

    let store: StoreDetails

    private var descriptionText: String {
        store.description.isEmpty ? "No description available." : store.description
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text("Stop \(store.stopNumber)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)

            Text(store.name)
                .font(.title2)
                .fontWeight(.bold)

            Text(descriptionText)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}

struct MapScreen: View {

    @StateObject private var vm = MapViewModel()

    var body: some View {

        ZStack {

            MappedinMapView(
                mapView: vm.mapView
            )
            .ignoresSafeArea()

            if vm.isLoading {

                ProgressView()
                    .scaleEffect(2)
            }
        }
        .sheet(item: $vm.selectedStore) { store in
            StoreDetailsSheet(store: store)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {

            if !vm.isMapReady {
                vm.loadMap()
            }
        }
    }
}
