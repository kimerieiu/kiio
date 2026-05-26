import Foundation

struct ApiEnvelope<T: Decodable>: Decodable {
    let code: Int
    let msg: String?
    let data: T?
}

struct EmptyRequest: Encodable {}

struct EmptyResponse: Decodable {}

struct PageData<T: Decodable>: Decodable {
    let total: Int
    let list: [T]
}
