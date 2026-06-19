//
//  NavigationManager.swift
//  StoreMap
//
//  Created by ajith.a.s on 16/06/26.
//

import Foundation
import Mappedin
import UIKit

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

        guard let firstCoordinate = legs.first?.directions.coordinates.first else {
            return
        }

        storeMarkerDetails = []

        // Entrance Marker
        addMarker(
            title: "",
            subtitle: nil,
            color: "#1871fb",
            target: firstCoordinate,
            compact: true
        )

        for (index, leg) in legs.enumerated() {
            
            guard let coordinate = leg.directions.coordinates.last else {
                continue
            }

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

            let html: String

            // Apple -> map asset
            if leg.destination.name == "Apple" {

                html = markerHTML(
                    imageName: "map"
                )

            } else {
                let randomCount = Int.random(in: 2...9)

                html = markerHTML(
                    imageName: "location",
                    count: randomCount
                )
            }

            mapView.markers.add(
                target: coordinate,
                html: html,
                options: AddMarkerOptions(
                    interactive: .True,
                    rank: .tier(.alwaysVisible)
                )
            ) { result in

                switch result {

                case .success:
                    print("Marker Added")

                case .failure(let error):
                    print("Marker Error: \(error)")
                }
            }
        }
        
        // Ensure final destination has an explicit annotation
        if let finalCoordinate = legs.last?.directions.coordinates.last {
            addMarker(
                title: "End",
                subtitle: nil,
                color: "#d92d20",
                target: finalCoordinate,
                compact: true
            )
        }
    }
    private func base64Image(named imageName: String) -> String? {

        guard let image = UIImage(named: imageName),
              let data = image.pngData() else {
            print("Image not found: \(imageName)")
            return nil
        }

        return data.base64EncodedString()
    }

    private func markerHTML(
        imageName: String,
        count: Int? = nil
    ) -> String {

        guard let base64 = base64Image(named: imageName) else {
            return """
            <div style="
                width:40px;
                height:40px;
                background:red;
                border-radius:20px;
                display:flex;
                align-items:center;
                justify-content:center;
                color:white;
                font-weight:bold;
            ">
                X
            </div>
            """
        }

        let countHTML: String

        if let count {
            countHTML = """
            <div style="
                position:absolute;
                top:4px;
                left:10px;
                width:20px;
                height:20px;
                border-radius:10px;
                background:white;
                display:flex;
                align-items:center;
                justify-content:center;
                color:black;
                font-size:12px;
                font-weight:800;
                box-shadow:0px 1px 3px rgba(0,0,0,0.25);
            ">
                \(count)
            </div>
            """
        } else {
            countHTML = ""
        }

        return """
        <div style="
            position:relative;
            width:44px;
            height:44px;
        ">

            <img
                src="data:image/png;base64,\(base64)"
                width="44"
                height="44"
            />

            \(countHTML)

        </div>
        """
    }
    
    private func addMarker(
        title: String,
        subtitle: String?,
        color: String,
        target: Coordinate,
        compact: Bool = false
    ) {
        let gap = compact ? 4 : 6
        let paddingY = compact ? 2 : 4
        let paddingX = compact ? 6 : 8
        let fontSize = compact ? 11 : 12
        let badgeSize = compact ? 18 : 20
        let borderRadius = compact ? 12 : 14
        
        let subtitleHTML: String = {
            if let subtitle, !subtitle.isEmpty {
                return "<span>\(subtitle)</span>"
            } else {
                return ""
            }
        }()
        
        let markerHtml = """
        <div style="
            display: inline-flex;
            align-items: center;
            gap: \(gap)px;
            background: white;
            border: 2px solid \(color);
            border-radius: \(borderRadius)px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            color: #111827;
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: \(fontSize)px;
            font-weight: 600;
            padding: \(paddingY)px \(paddingX)px;
            white-space: nowrap;
        ">
            <span style="
                align-items: center;
                background: \(color);
                border-radius: 50%;
                color: white;
                display: inline-flex;
                height: \(badgeSize)px;
                justify-content: center;
                min-width: \(badgeSize)px;
            ">\(title)</span>
            \(subtitleHTML)
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

