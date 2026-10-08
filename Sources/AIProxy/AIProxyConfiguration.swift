//
//  AIProxyConfiguration.swift
//  AIProxy
//
//  Created by Lou Zell on 7/31/25.
//

nonisolated struct AIProxyConfiguration {

    let resolveDNSOverTLS: Bool
    let printRequestBodies: Bool
    let printResponseBodies: Bool
    let useStableID: Bool
    let verificationMethod: AIProxyVerificationMethod
    var stableID: String?

    @AIProxyActor static internal func getStableIdentifier() async -> String? {
        #if !DEBUG
        if let appTransactionID = await AIProxyUtils.getAppTransactionID() {
            return appTransactionID
        }
        #endif
        do {
            return try await AnonymousAccountStorage.sync()
        } catch {
            logIf(.error)?.error("AIProxy: Could not configure an anonymous account: \(error.localizedDescription)")
        }
        return nil
    }
}
