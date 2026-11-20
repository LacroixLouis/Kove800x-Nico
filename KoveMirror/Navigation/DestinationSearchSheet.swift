import SwiftUI
import MapKit
import Combine

class SearchCompleterDelegate: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    func search(query: String, region: MKCoordinateRegion?) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        if let region = region {
            completer.region = region
        }
        completer.queryFragment = query
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
            self.isSearching = false
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isSearching = false
        }
    }
}

struct DestinationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var completerDelegate = SearchCompleterDelegate()
    @State private var query: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isPerformingSearch = false
    
    let userRegion: MKCoordinateRegion?
    let onSelectDestination: (MKMapItem) -> Void
    
    let categories: [(name: String, icon: String, query: String)] = [
        ("Stations-service", "fuelpump.fill", "Gas Station"),
        ("Café", "cup.and.saucer.fill", "Coffee Shop"),
        ("Parking", "parkingsign.circle.fill", "Motorcycle Parking"),
        ("Restaurant", "fork.knife", "Restaurant")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                RideTheme.background.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(RideTheme.muted)
                        
                        TextField("Destination ou adresse…", text: $query)
                            .foregroundColor(RideTheme.ink)
                            .onChange(of: query) { oldValue, newValue in
                                completerDelegate.search(query: newValue, region: userRegion)
                            }
                        
                        if !query.isEmpty {
                            Button(action: { query = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(RideTheme.muted)
                            }
                        }
                    }
                    .padding(12)
                    .background(RivetCockpit.panel)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Category Buttons Bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories, id: \.name) { cat in
                                Button(action: { performCategorySearch(cat.query) }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(RivetCockpit.lime)
                                        Text(cat.name)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(RideTheme.ink)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(RivetCockpit.raised)
                                    .cornerRadius(20)
                                    .overlay(
                                        Capsule()
                                            .stroke(RivetCockpit.line, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Search Results List
                    if isPerformingSearch || completerDelegate.isSearching {
                        VStack(spacing: 12) {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: RivetCockpit.lime))
                            Text("Recherche en cours…")
                                .font(.caption)
                                .foregroundColor(RideTheme.muted)
                            Spacer()
                        }
                    } else if !searchResults.isEmpty {
                        // Category Search Results
                        List {
                            ForEach(searchResults, id: \.self) { item in
                                MapItemRow(item: item) {
                                    onSelectDestination(item)
                                    dismiss()
                                }
                            }
                            .listRowBackground(RivetCockpit.panel)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    } else if !completerDelegate.results.isEmpty {
                        // Autocomplete Search Results
                        List {
                            ForEach(completerDelegate.results, id: \.self) { completion in
                                Button(action: { selectCompletion(completion) }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(RivetCockpit.orange)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(completion.title)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(RideTheme.ink)
                                            
                                            if !completion.subtitle.isEmpty {
                                                Text(completion.subtitle)
                                                    .font(.caption)
                                                    .foregroundColor(RideTheme.muted)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(RivetCockpit.panel)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    } else {
                        // Empty State / Instructions
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "map.circle.fill")
                                .font(.system(size: 54))
                                .foregroundColor(RivetCockpit.orange.opacity(0.65))
                            
                            Text("Trouve ta route")
                                .font(.headline)
                                .foregroundColor(RideTheme.ink)
                            
                            Text("Cherche une adresse, une ville ou un lieu pour préparer ton itinéraire.")
                                .font(.caption)
                                .foregroundColor(RideTheme.muted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Ta destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(RivetCockpit.orange)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(RivetCockpit.lime)
        .toolbarBackground(RivetCockpit.asphalt, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .presentationBackground(RivetCockpit.asphalt)
    }
    
    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        isPerformingSearch = true
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isPerformingSearch = false
                if let item = response?.mapItems.first {
                    self.onSelectDestination(item)
                    self.dismiss()
                }
            }
        }
    }
    
    private func performCategorySearch(_ categoryQuery: String) {
        isPerformingSearch = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = categoryQuery
        if let region = userRegion {
            request.region = region
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isPerformingSearch = false
                if let items = response?.mapItems {
                    self.searchResults = items
                }
            }
        }
    }
}

struct MapItemRow: View {
    let item: MKMapItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(RivetCockpit.orange)
                    .frame(width: 32, height: 32)
                    .background(RivetCockpit.orange.opacity(0.12))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Lieu")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(RideTheme.ink)
                    
                    if let address = item.name ?? item.address?.shortAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(RideTheme.muted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(RideTheme.muted)
            }
            .padding(.vertical, 4)
        }
    }
}
