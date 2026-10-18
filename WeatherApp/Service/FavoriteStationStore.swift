import Foundation
import SwiftData

enum FavoriteStationStoreError: Error {
    case unknownStation
    case missingFavorite
    case invalidOrder
}

@MainActor
struct FavoriteStationStore {
    let context: ModelContext
    private let saveChanges: (ModelContext) throws -> Void

    init(context: ModelContext, saveChanges: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.context = context
        self.saveChanges = saveChanges
    }

    func favorites() throws -> [FavoriteStation] {
        try context.fetch(FetchDescriptor<FavoriteStation>(sortBy: [
            SortDescriptor(\.sortOrder), SortDescriptor(\.stationID)
        ]))
    }

    @discardableResult
    func add(stationID: String, label: String = "") throws -> FavoriteStation {
        guard StationCoordinateStore.station(withID: stationID) != nil else {
            throw FavoriteStationStoreError.unknownStation
        }
        let saved = try favorites()
        // Repeated taps must preserve the existing label and display order.
        if let existing = saved.first(where: { $0.stationID == stationID }) { return existing }
        let favorite = FavoriteStation(stationID: stationID, label: label,
                                       sortOrder: (saved.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(favorite)
        try save()
        return favorite
    }

    func updateLabel(stationID: String, label: String) throws {
        guard let favorite = try favorites().first(where: { $0.stationID == stationID }) else {
            throw FavoriteStationStoreError.missingFavorite
        }
        favorite.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        try save()
    }

    func remove(stationIDs: Set<String>) throws {
        let saved = try favorites()
        for favorite in saved where stationIDs.contains(favorite.stationID) { context.delete(favorite) }
        for (index, favorite) in saved.filter({ !stationIDs.contains($0.stationID) }).enumerated() {
            favorite.sortOrder = index
        }
        try save()
    }

    func move(from offsets: IndexSet, to destination: Int) throws {
        let saved = try favorites()
        guard (0...saved.count).contains(destination), offsets.allSatisfy({ saved.indices.contains($0) }) else {
            throw FavoriteStationStoreError.invalidOrder
        }
        let moving = offsets.sorted().map { saved[$0] }
        var remaining = saved.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        let insertion = destination - offsets.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: insertion)
        for (index, favorite) in remaining.enumerated() { favorite.sortOrder = index }
        try save()
    }

    private func save() throws {
        do { try saveChanges(context) }
        catch {
            context.rollback()
            throw error
        }
    }
}

enum FavoritesPersistence {
    @MainActor
    static func makeContainer(storeURL: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([FavoriteStation.self])
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration("Favorites", schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration("Favorites", schema: schema, isStoredInMemoryOnly: inMemory,
                                               groupContainer: .none, cloudKitDatabase: .none)
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        // Changes are saved explicitly so failures can be reported and rolled back.
        container.mainContext.autosaveEnabled = false
        return container
    }
}
