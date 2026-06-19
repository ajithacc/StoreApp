//
//  StoreSelectionView.swift
//  StoreMap
//
//  Created by ajith.a.s on 19/06/26.
//
//
import Foundation
import SwiftUI

struct StoreSelectionView: View {

    let stores: [StoreItem]

    let selectedStores: Set<String>

    let onToggle: (StoreItem) -> Void

    let onStartRoute: () -> Void

    var body: some View {

        VStack {

            List(stores) { store in

                HStack {

                    Image(store.imageName)
                        .resizable()
                        .frame(
                            width: 40,
                            height: 40
                        )

                    Text(store.name)

                    Spacer()

                    if selectedStores.contains(
                        store.locationName
                    ) {

                        Image(systemName: "checkmark.circle.fill")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {

                    onToggle(store)
                }
            }

            Button("Start Navigation") {

                onStartRoute()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}
