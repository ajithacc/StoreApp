//
//  MapViewModel.swift
//  StoreMap
//
//  Created by ajith.a.s on 16/06/26.
//

import Foundation
import Mappedin
import SwiftUI
import Combine


class MapViewModel: ObservableObject {

    let mapView = MapView()

    private lazy var navigationManager = NavigationManager(mapView: mapView) { [weak self] storeDetails in
        DispatchQueue.main.async {
            self?.selectedStore = storeDetails
        }
    }

    @Published var isMapReady = false
    @Published var isLoading = false
    @Published var selectedStore: StoreDetails?

    func loadMap() {

        isLoading = true

        let options = GetMapDataWithCredentialsOptions(
            key: MapConfig.apiKey,
            secret: MapConfig.apiSecret,
            mapId: MapConfig.mapId
        )

        mapView.getMapData(options: options) { [weak self] result in

            guard let self = self else { return }

            switch result {

            case .success:

                self.mapView.show3dMap(
                    options: Show3DMapOptions()
                ) { result in

                    DispatchQueue.main.async {

                        self.isLoading = false

                        switch result {

                        case .success:
                            self.isMapReady = true
                            self.navigationManager.drawNearestItemRoute(
                                fromEntranceSpaceId: "s_6650b9a8cad393835892b92b",
                                destinationNames: [
                                    "Microsoft",
                                    "Apple",
                                    "Uniqlo",
                                    "Nespresso"
                                ]
                            )

                        case .failure(let error):
                            print(error)
                        }
                    }
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                }

                print(error)
            }
        }
    }

    deinit {
        mapView.destroy()
    }
}
