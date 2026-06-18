//
//  ContentView.swift
//  StoreMap
//
//  Created by ajith.a.s on 16/06/26.
//

import SwiftUI

struct ContentView: View {

    var body: some View {

        NavigationStack {

            MapScreen()
                .navigationTitle("Indoor Map")
        }
    }
}
