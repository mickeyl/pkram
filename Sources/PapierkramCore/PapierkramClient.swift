import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ListQuery: Sendable {
    public var page: Int?
    public var pageSize: Int?
    public var orderBy: String?
    public var orderDirection: String?
    public var filters: [String: String]

    public init(
        page: Int? = nil,
        pageSize: Int? = nil,
        orderBy: String? = nil,
        orderDirection: String? = nil,
        filters: [String: String] = [:]
    ) {
        self.page = page
        self.pageSize = pageSize
        self.orderBy = orderBy
        self.orderDirection = orderDirection
        self.filters = filters
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let page {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        if let pageSize {
            items.append(URLQueryItem(name: "page_size", value: String(pageSize)))
        }
        if let orderBy {
            items.append(URLQueryItem(name: "order_by", value: orderBy))
        }
        if let orderDirection {
            items.append(URLQueryItem(name: "order_direction", value: orderDirection))
        }
        for key in filters.keys.sorted() {
            items.append(URLQueryItem(name: key, value: filters[key]))
        }
        return items
    }
}

public struct NewTimeEntry: Encodable, Sendable {
    public struct Reference: Encodable, Sendable {
        public let id: Int
    }

    public let entryDate: String
    public let startedAtTime: String
    public let endedAtTime: String
    public let comments: String?
    public let unbillable: Bool?
    public let task: Reference?
    public let user: Reference

    public init(
        entryDate: String,
        startedAtTime: String,
        endedAtTime: String,
        comments: String?,
        unbillable: Bool?,
        taskID: Int?,
        userID: Int
    ) {
        self.entryDate = entryDate
        self.startedAtTime = startedAtTime
        self.endedAtTime = endedAtTime
        self.comments = comments
        self.unbillable = unbillable
        self.task = taskID.map(Reference.init(id:))
        self.user = Reference(id: userID)
    }

    enum CodingKeys: String, CodingKey {
        case entryDate = "entry_date"
        case startedAtTime = "started_at_time"
        case endedAtTime = "ended_at_time"
        case comments
        case unbillable
        case task
        case user
    }
}

public final class PapierkramClient {
    public static let version = "1.0.0"

    private let baseURL: URL
    private let subdomain: String
    private let token: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(config: PapierkramConfig, token: String, session: URLSession = .shared) throws {
        let subdomain = try Self.resolveSubdomain(config)
        guard let url = URL(string: "https://\(subdomain).papierkram.de/api/v1") else {
            throw PapierkramError.filesystem("'\(subdomain)' is not a usable Papierkram subdomain.")
        }
        self.subdomain = subdomain
        self.baseURL = url
        self.token = token
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    public convenience init(config: PapierkramConfig, tokenStore: KeychainTokenStore = KeychainTokenStore()) throws {
        let token = try tokenStore.readToken(account: Self.resolveSubdomain(config))
        try self.init(config: config, token: token)
    }

    /// The Papierkram subdomain the account lives under. There is deliberately no default:
    /// falling back to someone else's tenant would be worse than refusing to run.
    public static func resolveSubdomain(_ config: PapierkramConfig) throws -> String {
        guard let subdomain = config.subdomain?.trimmingCharacters(in: .whitespacesAndNewlines),
              !subdomain.isEmpty else {
            throw PapierkramError.subdomainMissing
        }
        return subdomain
    }

    public func listProjects(query: ListQuery = ListQuery()) async throws -> JSONValue {
        try await request("GET", path: "/projects", query: query.queryItems)
    }

    public func listTasks(query: ListQuery = ListQuery()) async throws -> JSONValue {
        try await request("GET", path: "/tracker/tasks", query: query.queryItems)
    }

    public func listTimeEntries(query: ListQuery = ListQuery()) async throws -> JSONValue {
        try await request("GET", path: "/tracker/time_entries", query: query.queryItems)
    }

    public func getProject(id: Int) async throws -> JSONValue {
        try await request("GET", path: "/projects/\(id)")
    }

    public func getTask(id: Int) async throws -> JSONValue {
        try await request("GET", path: "/tracker/tasks/\(id)")
    }

    public func getCompany(id: Int) async throws -> JSONValue {
        try await request("GET", path: "/contact/companies/\(id)")
    }

    public func createTimeEntry(_ entry: NewTimeEntry) async throws -> JSONValue {
        try await request("POST", path: "/tracker/time_entries", body: entry)
    }

    public func deleteTimeEntry(id: Int) async throws {
        let _: JSONValue = try await request("DELETE", path: "/tracker/time_entries/\(id)")
    }

    private func request<T: Encodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: T? = Optional<String>.none
    ) async throws -> JSONValue {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw PapierkramError.invalidResponse("Could not build URL for \(path).")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("pkram/\(PapierkramClient.version)", forHTTPHeaderField: "User-Agent")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PapierkramError.invalidResponse("Missing HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(decoding: data, as: UTF8.self)
            throw PapierkramError.api(
                status: httpResponse.statusCode,
                reason: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                body: body
            )
        }
        if httpResponse.statusCode == 204 || data.isEmpty {
            return .object([:])
        }
        return try decoder.decode(JSONValue.self, from: data)
    }
}
