import Foundation
import SwiftData

@Model
final class FavoriteStation {
    @Attribute(.unique) var stationID: String
    var label: String
    var sortOrder: Int

    init(stationID: String, label: String = "", sortOrder: Int = 0) {
        self.stationID = stationID
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sortOrder = sortOrder
    }
}
