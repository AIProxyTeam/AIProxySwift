//
//  MistralProxiedService.swift
//
//
//  Created by Lou Zell on 11/24/24.
//

import Foundation

@AIProxyActor final class MistralProxiedService: MistralService, ProxiedService, Sendable {

    /// This initializer is not public on purpose.
    /// Customers are expected to use the factory `AIProxy.mistralService` defined in AIProxy.swift
    nonisolated init(
        partialKey: String,
        serviceURL: String?,
        clientID: String?
    ) {
        let requestBuilder = AIProxyProxiedRequestBuilder(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
        super.init(
            requestBuilder: requestBuilder,
            serviceNetworker: ProxiedServiceNetworker()
        )
    }
}
