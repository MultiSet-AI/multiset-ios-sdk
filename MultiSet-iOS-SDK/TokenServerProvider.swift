/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import MultiSetSDK

// `?reason=rejected` tells the server its cached token was refused, so it must mint a new one.
struct TokenServerProvider: MultiSetTokenProvider {
    let url: URL

    func token(for reason: MultiSetTokenRequestReason) async throws -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        let queryItems = components.queryItems ?? []
        components.queryItems = queryItems + [URLQueryItem(name: "reason", value: "\(reason)")]
        guard let requestURL = components.url else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: requestURL)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data).token
    }

    private struct TokenResponse: Decodable {
        let token: String
    }
}
