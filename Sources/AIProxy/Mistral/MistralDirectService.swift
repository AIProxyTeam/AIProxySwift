//
//  MistralDirectService.swift
//
//
//  Created by Lou Zell on 12/19/24.
//

import Foundation

@AIProxyActor final class MistralDirectService: MistralService, DirectService, Sendable {

    /// This initializer is not public on purpose.
    /// Customers are expected to use the factory `AIProxy.mistralDirectService` defined in AIProxy.swift
    nonisolated init(
        unprotectedAPIKey: String,
        baseURL: String? = nil
    ) {
        let baseURL = baseURL ?? "https://api.mistral.ai"
        let requestBuilder = AIProxyDirectRequestBuilder(
            baseURL: baseURL,
            unprotectedAuthHeader: (key: "Authorization", value: "Bearer \(unprotectedAPIKey)")
        )
        super.init(
            requestBuilder: requestBuilder,
            serviceNetworker: DirectServiceNetworker()
        )
    }
}
