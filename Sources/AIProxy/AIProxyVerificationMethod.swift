//
//  AIProxyVerificationMethod.swift
//  AIProxy
//

/// How requests prove they come from your app on a real Apple device. Each
/// AIProxy service has one verification method, chosen in the dashboard; the
/// SDK must send the matching credential.
nonisolated public enum AIProxyVerificationMethod: Equatable, Sendable {
    /// Apple DeviceCheck. Every request carries a fresh token in `aiproxy-devicecheck`
    /// (or the `AIPROXY_DEVICE_CHECK_BYPASS` token on the Simulator). The default.
    case deviceCheck

    /// Apple App Attest. The install attests once, then every request carries an
    /// assertion signed by a Secure Enclave key in the `aiproxy-appattest-*` headers
    /// (or the `AIPROXY_APP_ATTEST_BYPASS` token on the Simulator).
    ///
    /// `appURL` names the AIProxy app the key is registered to: `https://api.aiproxy.com/<app>`,
    /// shown on the App Attest tab of the dashboard. It is any of your service URLs with the
    /// last path segment removed (a full service URL is accepted too). `AIProxy.configure`
    /// starts the one-time attestation for it in the background, so it happens at launch
    /// rather than on the user's first request. Requires a `serviceURL` on every service
    /// and the App Attest capability on your target.
    case appAttest(appURL: String)
}
