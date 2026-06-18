//
//  NavigationManager.swift
//  StoreMap
//
//  Created by ajith.a.s on 16/06/26.
//

import Foundation
import Mappedin

// Model structure for each pointers

struct StoreDetails: Identifiable {
    let name: String
    let description: String
    let stopNumber: Int
    
    var id: String {
        "\(stopNumber)-\(name)"
    }
}

// Class used for handling navigations

final class NavigationManager {
    
    // For paths
    
    private struct RouteLeg {
        let destination: EnterpriseLocation
        let directions: Directions
        let distance: Double
    }
    
    // Store details
    
    private struct StoreMarkerDetails {
        let details: StoreDetails
        let coordinate: Coordinate
    }
    
    private let mapView: MapView
    private let onStoreSelected: (StoreDetails?) -> Void
    private var storeMarkerDetails: [StoreMarkerDetails] = []
    
    init(
        mapView: MapView,
        onStoreSelected: @escaping (StoreDetails?) -> Void
    ) {
        self.mapView = mapView
        self.onStoreSelected = onStoreSelected
        registerMarkerTapHandler()
    }
    
    // function for routing the different directions
    
    func drawRoute(
        from originName: String,
        to destinationName: String
    ) {
        mapView.mapData.getByType(.enterpriseLocation) { [weak self] (result: Result<[EnterpriseLocation], Error>) in
            guard let self else { return }
            
            switch result {
            case .success(let locations):
                guard
                    let origin = locations.first(where: { $0.name == originName }),
                    let destination = locations.first(where: { $0.name == destinationName })
                else {
                    print("Could not find route locations: \(originName) to \(destinationName)")
                    return
                }
                
                self.mapView.mapData.getDirections(
                    from: .enterpriseLocation(origin),
                    to: .enterpriseLocation(destination)
                ) { [weak self] directionsResult in
                    guard let self else { return }
                    
                    switch directionsResult {
                    case .success(let directions):
                        guard let directions else {
                            print("No directions found from \(originName) to \(destinationName)")
                            return
                        }
                        
                        self.draw(directions: directions)
                        
                    case .failure(let error):
                        print("getDirections error: \(error)")
                    }
                }
                
            case .failure(let error):
                print("getByType enterpriseLocation error: \(error)")
            }
        }
    }
    
    func drawMultiStopRoute(through locationNames: [String]) {
        guard locationNames.count >= 2 else { return }
        
        mapView.mapData.getByType(.enterpriseLocation) { [weak self] (result: Result<[EnterpriseLocation], Error>) in
            guard let self else { return }
            
            switch result {
            case .success(let locations):
                let routeLocations = locationNames.compactMap { name in
                    locations.first { $0.name == name }
                }
                
                guard routeLocations.count == locationNames.count else {
                    let foundNames = Set(routeLocations.map(\.name))
                    let missingNames = locationNames.filter { !foundNames.contains($0) }
                    print("Could not find route locations: \(missingNames.joined(separator: ", "))")
                    return
                }
                
                guard let origin = routeLocations.first else { return }
                let destinations = routeLocations.dropFirst().map { location in
                    MultiDestinationTarget.single(.enterpriseLocation(location))
                }
                
                self.mapView.mapData.getDirectionsMultiDestination(
                    from: .enterpriseLocation(origin),
                    to: Array(destinations)
                ) { [weak self] directionsResult in
                    guard let self else { return }
                    
                    switch directionsResult {
                    case .success(let directions):
                        guard let directions, !directions.isEmpty else {
                            print("No multi-stop directions found for: \(locationNames.joined(separator: " -> "))")
                            return
                        }
                        
                        self.draw(directionsList: directions)
                        
                    case .failure(let error):
                        print("getDirectionsMultiDestination error: \(error)")
                    }
                }
                
            case .failure(let error):
                print("getByType enterpriseLocation error: \(error)")
            }
        }
    }
    
    func drawNearestItemRoute(
        fromEntranceSpaceId entranceSpaceId: String,
        destinationNames: [String]
    ) {
        guard !destinationNames.isEmpty else { return }
        
        mapView.mapData.getById(.space, id: entranceSpaceId) { [weak self] (startResult: Result<Space?, Error>) in
            guard let self else { return }
            
            guard case .success(let entrance?) = startResult else {
                print("Could not find entrance space: \(entranceSpaceId)")
                return
            }
            
            self.mapView.mapData.getByType(.enterpriseLocation) { [weak self] (locationsResult: Result<[EnterpriseLocation], Error>) in
                guard let self else { return }
                
                switch locationsResult {
                case .success(let locations):
                    let destinations = destinationNames.compactMap { name in
                        locations.first { $0.name == name }
                    }
                    
                    guard destinations.count == destinationNames.count else {
                        let foundNames = Set(destinations.map(\.name))
                        let missingNames = destinationNames.filter { !foundNames.contains($0) }
                        print("Could not find route destinations: \(missingNames.joined(separator: ", "))")
                        return
                    }
                    
                    self.buildNearestRoute(
                        from: .space(entrance),
                        remainingDestinations: destinations,
                        selectedLegs: []
                    ) { [weak self] legs in
                        self?.drawColoredRoute(legs: legs)
                    }
                    
                case .failure(let error):
                    print("getByType enterpriseLocation error: \(error)")
                }
            }
        }
    }
    
    private func draw(directions: Directions) {
        let pathOptions = AddPathOptions(interactive: true)
        let navigationOptions = NavigationOptions(pathOptions: pathOptions)
        
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.navigation.draw(
            directions: directions,
            options: navigationOptions
        ) { _ in }
    }
    
    private func draw(directionsList: [Directions]) {
        let pathOptions = AddPathOptions(interactive: true)
        let navigationOptions = NavigationOptions(pathOptions: pathOptions)
        
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.navigation.draw(
            directions: directionsList,
            options: navigationOptions
        ) { _ in }
    }
    
    private func buildNearestRoute(
        from currentTarget: NavigationTarget,
        remainingDestinations: [EnterpriseLocation],
        selectedLegs: [RouteLeg],
        completion: @escaping ([RouteLeg]) -> Void
    ) {
        guard !remainingDestinations.isEmpty else {
            completion(selectedLegs)
            return
        }
        
        var candidateLegs: [RouteLeg] = []
        var pendingDirectionsCount = remainingDestinations.count
        
        for destination in remainingDestinations {
            mapView.mapData.getDirections(
                from: currentTarget,
                to: .enterpriseLocation(destination)
            ) { [weak self] result in
                guard let self else { return }
                
                if case .success(let directions?) = result {
                    candidateLegs.append(
                        RouteLeg(
                            destination: destination,
                            directions: directions,
                            distance: self.totalDistance(for: directions)
                        )
                    )
                } else if case .failure(let error) = result {
                    print("getDirections error for \(destination.name): \(error)")
                }
                
                pendingDirectionsCount -= 1
                
                guard pendingDirectionsCount == 0 else { return }
                guard let nearestLeg = candidateLegs.min(by: { $0.distance < $1.distance }) else {
                    completion(selectedLegs)
                    return
                }
                
                let remaining = remainingDestinations.filter { $0.name != nearestLeg.destination.name }
                self.buildNearestRoute(
                    from: .enterpriseLocation(nearestLeg.destination),
                    remainingDestinations: remaining,
                    selectedLegs: selectedLegs + [nearestLeg],
                    completion: completion
                )
            }
        }
    }
    
    private func drawColoredRoute(legs: [RouteLeg]) {
        guard !legs.isEmpty else { return }
        
        mapView.navigation.clear()
        mapView.paths.removeAll()
        
        for (index, leg) in legs.enumerated() {
            let color = index == 0 ? "#1871fb" : "#d92d20"
            let pathOptions = AddPathOptions(
                color: color,
                width: .value(1.0)
            )
            
            mapView.paths.add(
                coordinates: leg.directions.coordinates,
                options: pathOptions
            ) { _ in }
        }
        
        addRouteMarkers(for: legs)
        focusCamera(on: legs)
    }
    
    private func addRouteMarkers(for legs: [RouteLeg]) {
        guard let firstCoordinate = legs.first?.directions.coordinates.first else { return }
        
        storeMarkerDetails = []
        
        addMarker(
            title: "Start",
            subtitle: "Entrance",
            color: "#1871fb",
            target: firstCoordinate
        )
        
        for (index, leg) in legs.enumerated() {
            guard let coordinate = leg.directions.coordinates.last else { continue }
            
            storeMarkerDetails.append(
                StoreMarkerDetails(
                    details: StoreDetails(
                        name: leg.destination.name,
                        description: leg.destination.description ?? "",
                        stopNumber: index + 1
                    ),
                    coordinate: coordinate
                )
            )
            
            addMarker(
                title: "\(index + 1)",
                subtitle: leg.destination.name,
                color: index == 0 ? "#1871fb" : "#d92d20",
                target: coordinate
            )
        }
    }
    
    private func addMarker(
        title: String,
        subtitle: String,
        color: String,
        target: Coordinate
    ) {
        let markerHtml = """
        <div style="
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: white;
            border: 2px solid \(color);
            border-radius: 14px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            color: #111827;
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: 12px;
            font-weight: 600;
            padding: 4px 8px;
            white-space: nowrap;
        ">
            <span style="
                align-items: center;
                background: \(color);
                border-radius: 50%;
                color: white;
                display: inline-flex;
                height: 20px;
                justify-content: center;
                min-width: 20px;
            ">\(title)</span>
            <span>\(subtitle)</span>
        </div>
        """
        
        mapView.markers.add(
            target: target,
            html: markerHtml,
            options: AddMarkerOptions(
                interactive: .True,
                rank: .tier(.alwaysVisible)
            )
        ) { _ in }
    }
    
    private func registerMarkerTapHandler() {
        mapView.on(Events.click) { [weak self] clickPayload in
            guard let self, let clickPayload else { return }
            
            guard let markers = clickPayload.markers, !markers.isEmpty else {
                self.onStoreSelected(nil)
                return
            }
            
            guard let markerDetails = self.nearestStoreMarker(to: clickPayload.coordinate) else { return }
            self.onStoreSelected(markerDetails.details)
        }
    }
    
    private func nearestStoreMarker(to coordinate: Coordinate) -> StoreMarkerDetails? {
        storeMarkerDetails.min { first, second in
            distanceSquared(from: coordinate, to: first.coordinate) < distanceSquared(from: coordinate, to: second.coordinate)
        }
    }
    
    private func distanceSquared(
        from first: Coordinate,
        to second: Coordinate
    ) -> Double {
        let latitudeDifference = first.latitude - second.latitude
        let longitudeDifference = first.longitude - second.longitude
        
        return latitudeDifference * latitudeDifference + longitudeDifference * longitudeDifference
    }
    
    private func focusCamera(on legs: [RouteLeg]) {
        let targets = legs.flatMap { leg in
            leg.directions.coordinates.map { FocusTarget.coordinate($0) }
        }
        
        guard !targets.isEmpty else { return }
        mapView.camera.focusOn(targets: targets)
    }
    
    private func totalDistance(for directions: Directions) -> Double {
        directions.instructions.reduce(0) { total, instruction in
            total + instruction.distance
        }
    }
}
