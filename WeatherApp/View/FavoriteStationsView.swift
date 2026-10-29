import SwiftUI
import SwiftData

struct FavoriteStationsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\FavoriteStation.sortOrder), SortDescriptor(\FavoriteStation.stationID)])
    private var favorites: [FavoriteStation]
    @State private var isAdding = false
    @State private var editingFavorite: FavoriteStation?
    @State private var saveFailed = false

    private var language: String { settings.apiLanguageCode }

    var body: some View {
        List {
            if favorites.isEmpty {
                ContentUnavailableView {
                    Label(settings.text("favorites_empty_title"), systemImage: "star")
                } description: {
                    Text(settings.text("favorites_empty_message"))
                } actions: {
                    Button(settings.text("favorites_add")) { isAdding = true }
                }
            } else {
                Section {
                    ForEach(favorites) { favorite in
                        Button {
                            editingFavorite = favorite
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(favorite.label.isEmpty ? stationName(favorite) : favorite.label)
                                    .foregroundStyle(.primary)
                                if !favorite.label.isEmpty {
                                    Text(stationName(favorite)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .onDelete(perform: remove)
                    .onMove(perform: move)
                } footer: {
                    Text(settings.text("favorites_manage_help"))
                }
            }
        }
        .navigationTitle(settings.text("favorites_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAdding = true } label: {
                    Label(settings.text("favorites_add"), systemImage: "plus")
                }
            }
            if !favorites.isEmpty {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
        .sheet(isPresented: $isAdding) { FavoriteStationPickerView() }
        .sheet(item: $editingFavorite) { favorite in
            NavigationStack {
                FavoriteStationEditorView(stationID: favorite.stationID, favorite: favorite) {
                    editingFavorite = nil
                }
            }
        }
        .alert(settings.text("favorites_save_error_title"), isPresented: $saveFailed) {
            Button(settings.text("weather_close"), role: .cancel) {}
        } message: {
            Text(settings.text("favorites_save_error_message"))
        }
    }

    private func stationName(_ favorite: FavoriteStation) -> String {
        StationCoordinateStore.station(withID: favorite.stationID)?.name(lang: language) ?? favorite.stationID
    }

    private func remove(at offsets: IndexSet) {
        let ids = Set(offsets.map { favorites[$0].stationID })
        do { try FavoriteStationStore(context: context).remove(stationIDs: ids) }
        catch { saveFailed = true }
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        do { try FavoriteStationStore(context: context).move(from: offsets, to: destination) }
        catch { saveFailed = true }
    }
}

private struct FavoriteStationPickerView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Query private var favorites: [FavoriteStation]
    @State private var search = ""

    private var available: [StationCoordinate] {
        let savedIDs = Set(favorites.map(\.stationID))
        return StationCoordinateStore.stations(matching: search, lang: settings.apiLanguageCode)
            .filter { !savedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if available.isEmpty {
                    ContentUnavailableView(settings.text("favorites_no_stations"), systemImage: "magnifyingglass")
                }
                ForEach(available) { station in
                    NavigationLink {
                        FavoriteStationEditorView(stationID: station.id) { dismiss() }
                    } label: {
                        Text(station.name(lang: settings.apiLanguageCode))
                    }
                }
            }
            .searchable(text: $search, prompt: settings.text("favorites_search"))
            .navigationTitle(settings.text("favorites_choose_station"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.text("favorites_cancel")) { dismiss() }
                }
            }
        }
    }
}

private struct FavoriteStationEditorView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let stationID: String
    let favorite: FavoriteStation?
    let onSaved: () -> Void
    @State private var label: String
    @State private var saveFailed = false

    init(stationID: String, favorite: FavoriteStation? = nil, onSaved: @escaping () -> Void) {
        self.stationID = stationID
        self.favorite = favorite
        self.onSaved = onSaved
        _label = State(initialValue: favorite?.label ?? "")
    }

    var body: some View {
        Form {
            Section(settings.text("favorites_station")) {
                Text(StationCoordinateStore.station(withID: stationID)?.name(lang: settings.apiLanguageCode) ?? stationID)
            }
            Section {
                TextField(settings.text("favorites_label_placeholder"), text: $label)
                    .accessibilityLabel(settings.text("favorites_label"))
            } header: {
                Text(settings.text("favorites_label"))
            } footer: {
                Text(settings.text("favorites_label_help"))
            }
        }
        .navigationTitle(settings.text(favorite == nil ? "favorites_add" : "favorites_edit_label"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(settings.text("favorites_cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(settings.text("favorites_save"), action: save)
            }
        }
        .alert(settings.text("favorites_save_error_title"), isPresented: $saveFailed) {
            Button(settings.text("weather_close"), role: .cancel) {}
        } message: {
            Text(settings.text("favorites_save_error_message"))
        }
    }

    private func save() {
        let store = FavoriteStationStore(context: context)
        do {
            if favorite != nil { try store.updateLabel(stationID: stationID, label: label) }
            else { try store.add(stationID: stationID, label: label) }
            onSaved()
        } catch {
            saveFailed = true
        }
    }
}
