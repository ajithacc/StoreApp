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
    
    @Published var availableStores: [StoreItem] = []
    @Published var showStoreSelectionSheet = false
    
    @Published var selectedStores: Set<String> = []
    
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
                    
                    self.isLoading = false
                    
                    self.isMapReady = true
                    
                    self.availableStores = [
                        StoreItem(
                            name: "Microsoft",
                            imageName: "microsoft",
                            locationName: "Microsoft"
                        ),
                        StoreItem(
                            name: "Apple",
                            imageName: "apple",
                            locationName: "Apple"
                        ),
                        StoreItem(
                            name: "Uniqlo",
                            imageName: "uniqlo",
                            locationName: "Uniqlo"
                        ),
                        StoreItem(
                            name: "Nespresso",
                            imageName: "nespresso",
                            locationName: "Nespresso"
                        )
                    ]
                    
                    self.showStoreSelectionSheet = true
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
                print(error)
            }
        }
    }
    
    func drawRouteToStore(
        _ storeName: String
    ) {
        
        navigationManager.drawNearestItemRoute(
            fromEntranceSpaceId: "s_6650b9a8cad393835892b92b",
            destinationNames: [storeName]
        )
    }
    func toggleStoreSelection(
        _ store: StoreItem
    ) {
        
        if selectedStores.contains(store.locationName) {
            
            selectedStores.remove(store.locationName)
            
        } else {
            
            selectedStores.insert(store.locationName)
        }
    }
    
    func startShoppingRoute() {
        
        guard !selectedStores.isEmpty else {
            
            return
            
        }
        
        navigationManager.drawNearestItemRoute(
            
            fromEntranceSpaceId: "s_6650b9a8cad393835892b92b",
            
            destinationNames: Array(selectedStores)
            
        )
    }
    
    deinit {
        mapView.destroy()
    }
}
