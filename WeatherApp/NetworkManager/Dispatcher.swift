//
//  Dispatcher.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 9/8/2022.
//

import Foundation
import Combine

enum NetworkRequestError: LocalizedError, Equatable {
    case invalidRequest
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case error4xx(_ code: Int)
    case serverError
    case error5xx(_ code: Int)
    case decodingError
    case urlSessionFailed(_ error: URLError)
    case unknownError
}

struct Dispatcher {
    let urlSession: URLSession!
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    func dispatch<ReturnType: Codable>(request: URLRequest) -> AnyPublisher<ReturnType, NetworkRequestError> {
        return urlSession
            .dataTaskPublisher(for: request)
            .tryMap({ (data, response) in
                if let response = response as? HTTPURLResponse, !(200 ... 299).contains(response.statusCode) {
                    throw httpError(response.statusCode)
                }
                return data
            })
            .decode(type: ReturnType.self, decoder: JSONDecoder())
            .mapError({ (error) in
                handleError(error)
            })
            .eraseToAnyPublisher()
    }
}

extension Dispatcher {
    private func httpError(_ statusCode: Int) -> NetworkRequestError {
        switch statusCode {
        case 400:
            return .badRequest
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 402, 405 ... 409:
            return .error4xx(statusCode)
        case 500:
            return .serverError
        case 501 ... 599:
            return .error5xx(statusCode)
        default:
            return .unknownError
        }
    }
    
    private func handleError(_ error: Error) -> NetworkRequestError {
        switch error {
        case is Swift.DecodingError:
            return .decodingError
        case let urlError as URLError:
            return .urlSessionFailed(urlError)
        case let error as NetworkRequestError:
            return error
        default:
            return .unknownError
        }
    }
}
