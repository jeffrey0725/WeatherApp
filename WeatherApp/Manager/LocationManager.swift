import Foundation
import Combine
import CoreLocation

enum LocationLookupError: Error, Equatable {
    case denied, restricted, timedOut, unavailable
    var titleKey: String {
        switch self {
        case .denied: return "nearby_location_denied"
        case .restricted: return "nearby_location_restricted"
        case .timedOut: return "nearby_location_timeout"
        case .unavailable: return "nearby_location_unavailable"
        }
    }
}

enum LocationAuthorization {
    case notDetermined, restricted, denied, authorizedWhenInUse, authorizedAlways, unavailable
    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorizedWhenInUse: self = .authorizedWhenInUse
        case .authorizedAlways: self = .authorizedAlways
        @unknown default: self = .unavailable
        }
    }
}

enum LocationClientEvent {
    case authorization(LocationAuthorization)
    case locations([CLLocation])
    case failure(Error)
}

@MainActor
protocol LocationRequestClient: AnyObject {
    var authorizationStatus: LocationAuthorization { get }
    var onEvent: ((LocationClientEvent) -> Void)? { get set }
    func requestWhenInUseAuthorization()
    func requestLocation()
    func stop()
}

@MainActor
final class LocationManager: ObservableObject {
    @Published private(set) var location: CLLocation?
    @Published private(set) var failure: LocationLookupError?
    @Published private(set) var isLocating = false
    private let client: any LocationRequestClient
    private let now: () -> Date
    private let timeoutNanoseconds: UInt64
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var activeRequest: UUID?
    private var timeoutTask: Task<Void, Never>?
    private var requestedAuthorization = false
    private var requestedFix = false

    init(client: (any LocationRequestClient)? = nil, now: @escaping () -> Date = Date.init,
         timeoutNanoseconds: UInt64 = 20_000_000_000) {
        self.client = client ?? CoreLocationRequestClient()
        self.now = now
        self.timeoutNanoseconds = timeoutNanoseconds
        self.client.onEvent = { [weak self] event in self?.handle(event) }
    }

    // Only an explicit user action starts authorization or a location lookup.
    func locate() async {
        guard activeRequest == nil else { return }
        let requestID = UUID()
        activeRequest = requestID
        isLocating = true
        location = nil
        failure = nil
        requestedAuthorization = false
        requestedFix = false
        defer {
            if activeRequest == requestID {
                activeRequest = nil
                isLocating = false
            }
        }
        do {
            let fix = try await withTaskCancellationHandler {
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation
                    authorize(client.authorizationStatus)
                }
            } onCancel: {
                Task { @MainActor [weak self] in self?.cancel(requestID: requestID) }
            }
            guard activeRequest == requestID, !Task.isCancelled else { return }
            location = fix
        } catch is CancellationError {
        } catch {
            guard activeRequest == requestID else { return }
            failure = error as? LocationLookupError ?? .unavailable
        }
    }

    func cancel() {
        location = nil
        failure = nil
        guard activeRequest != nil else { return }
        activeRequest = nil
        isLocating = false
        finish(.failure(CancellationError()))
    }

    private func cancel(requestID: UUID) {
        guard activeRequest == requestID else { return }
        cancel()
    }

    private func authorize(_ status: LocationAuthorization) {
        switch status {
        case .notDetermined:
            if !requestedAuthorization {
                requestedAuthorization = true
                client.requestWhenInUseAuthorization()
            }
        case .authorizedAlways, .authorizedWhenInUse:
            guard !requestedFix else { return }
            requestedFix = true
            let requestID = activeRequest
            let timeout = timeoutNanoseconds
            timeoutTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: timeout) } catch { return }
                guard let self, self.activeRequest == requestID else { return }
                self.finish(.failure(LocationLookupError.timedOut))
            }
            client.requestLocation()
        case .denied: finish(.failure(LocationLookupError.denied))
        case .restricted: finish(.failure(LocationLookupError.restricted))
        case .unavailable: finish(.failure(LocationLookupError.unavailable))
        }
    }

    private func handle(_ event: LocationClientEvent) {
        guard continuation != nil, activeRequest != nil else { return }
        switch event {
        case .authorization(let status): authorize(status)
        case .locations(let locations):
            guard requestedFix else { return }
            let valid = locations.filter { LocationFixPolicy.isValid($0, at: now()) }
            guard let fix = valid.max(by: { $0.timestamp < $1.timestamp }) else {
                finish(.failure(LocationLookupError.unavailable))
                return
            }
            finish(.success(fix))
        case .failure(let error):
            let denied = (error as? CLError)?.code == .denied
            finish(.failure(denied ? LocationLookupError.denied : .unavailable))
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        client.stop()
        continuation.resume(with: result)
    }
}

@MainActor
private final class CoreLocationRequestClient: NSObject, LocationRequestClient, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    var onEvent: ((LocationClientEvent) -> Void)?
    var authorizationStatus: LocationAuthorization { LocationAuthorization(manager.authorizationStatus) }

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = self
    }
    func requestWhenInUseAuthorization() { manager.requestWhenInUseAuthorization() }
    func requestLocation() { manager.requestLocation() }
    func stop() { manager.stopUpdatingLocation() }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in self?.onEvent?(.authorization(LocationAuthorization(status))) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in self?.onEvent?(.locations(locations)) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.onEvent?(.failure(error)) }
    }
}
