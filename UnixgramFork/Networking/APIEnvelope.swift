import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: APIErrorPayload?
}

struct APIErrorPayload: Decodable, Error {
    let code: String
    let message: String
    let details: [String]?
}
