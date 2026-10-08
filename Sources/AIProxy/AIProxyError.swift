//
//  AIProxyError.swift
//
//
//  Created by Lou Zell on 6/23/24.
//

import Foundation

nonisolated public enum AIProxyError: LocalizedError, Equatable, Sendable {

    /// This error is thrown if any programmer assumptions are broken and the library can't continue.
    ///
    /// In application code, this would normally be a FatalError. It's tempting to use FatalError for
    /// broken invariants here, but as a library author I never want an application to crash in
    /// production because of us. If `FatalError` was used for broken library invariants, then an
    /// insufficiently tested codepath could crash an app that depends on us.
    ///
    /// One alternative is to use the built-in `AssertionError` in library code, but that muddles
    /// library interfaces: Any function f -> g that used `AssertionError` would become f -> g?
    /// because AssertionError is not an enforced precondition in production. The program won't halt
    /// and you need to figure out what to return.
    ///
    /// I prefer the alternative of defining `AIProxyError.assertion`, which is thrown for broken
    /// invariants. Interfaces that already `throw` remain unchanged when `AIProxyError.assertion`
    /// is introduced in the function body. Interfaces that did not throw before the introduction of
    /// `AIProxyError.assertion` will need to change, but I consider that worthwhile. Reasonable
    /// people would disagree, and think the introduction of a broken invariant should change a
    /// non-throwing library function from f -> g to f -> g?, but I consider the burden imposed on the
    /// caller to be similar for unwrapping the optional versus handling an error.
    ///
    /// Any AIProxyError.assertion that you encounter in the wild is a programmer error.
    /// Please contact support@aiproxy.com with a reproduction!
    case assertion(String)


    /// Raised when the status code of a network response is outside of the [200, 299] range.
    /// The associated Int contains the status code of the failed request.
    /// The associated String contains the response body of the failed request.
    ///
    /// A status code that you may experience in normal operation of your app is a 429, which
    /// means that your request was rate limited. A simple way to test this during development is
    /// to place a really low rate limit in the AIProxy dashboard, and then fire a couple requests
    /// from the simulator to reach the rate limit. You wouldn't want to do this once your app is in
    /// production, because the rate limits that you apply will rate limit live users!
    case unsuccessfulRequest(statusCode: Int, responseBody: String)

    /// A core component of our security model is Apple's DeviceCheck.
    /// If we can't generate a DeviceCheck token, then the app is not allowed to make requests to AIProxy's backend.
    /// Catch this error to pop UI to the end user.
    /// Our suggested copy for the alert is:
    /// "We could not create a required credential to make your AI request. Please make sure you are connected to the internet and your system clock is accurately set."
    case deviceCheckIsUnavailable

    /// Raised from the iOS simulator if the `AIPROXY_DEVICE_CHECK_BYPASS` token is not set.
    /// The bypass token is needed on simulators only, where Apple's DeviceCheck is not available.
    case deviceCheckBypassIsMissing

    /// App Attest is not supported on this device (the Simulator, or hardware without a Secure Enclave)
    /// and no `AIPROXY_APP_ATTEST_BYPASS` token is set. Raised only when the SDK is configured with
    /// `verificationMethod: .appAttest`.
    case appAttestIsUnavailable

    /// Raised from the iOS simulator if the `AIPROXY_APP_ATTEST_BYPASS` token is not set.
    /// App Attest does not exist on simulators, so the bypass token stands in for it during development.
    case appAttestBypassIsMissing

    /// App Attest needs the app and service segments of a `serviceURL` to find its attestation routes.
    /// Raised when a service was created without a `serviceURL` (the legacy `api.aiproxy.pro` form).
    case appAttestRequiresServiceURL

    /// Apple reported the device's App Attest key as invalid, and attesting a replacement also failed.
    case appAttestKeyInvalidated

    /// AIProxy answered the App Attest challenge or register route with a non-2xx status.
    /// The body names the cause (for example a bundle ID that does not match the dashboard).
    /// `retryAfter` is set when the server sent `Retry-After`.
    case appAttestRegistrationFailed(statusCode: Int, responseBody: String, retryAfter: TimeInterval?)

    /// A recent App Attest registration failed, and the SDK is waiting before trying again.
    /// `cause` describes the failure that started the backoff.
    case appAttestRegistrationBackingOff(until: Date, cause: String)

    /// AIProxy answered an attestation route with a body the SDK could not interpret.
    case appAttestMalformedResponse(route: String)

    /// Reading or writing the App Attest key ID in the Keychain failed.
    case appAttestKeychainError(status: Int32)

    public var errorDescription: String? {
        switch self {
        case .assertion(let message):
            return "AIProxy - A library precondition was not met: \(message)"
        case .unsuccessfulRequest(statusCode: let statusCode, responseBody: let responseBody):
            return "AIProxy - the request resulted in a status code of \(statusCode) with response body: \(responseBody)."
        case .deviceCheckIsUnavailable:
            return "AIProxy - Apple's DeviceCheck is not available on this device. Please make sure you are connected to the internet and your system clock is accurately set."
        case .deviceCheckBypassIsMissing:
            return "AIProxy - You are running on a simulator without setting the AIPROXY_DEVICE_CHECK_BYPASS env variable. Please see the integration guide for instructions on setting AIPROXY_DEVICE_CHECK_BYPASS: https://www.aiproxy.com/docs/integration-guide.html"
        case .appAttestIsUnavailable:
            return "AIProxy - Apple's App Attest is not available on this device, and no AIPROXY_APP_ATTEST_BYPASS env variable is set. App Attest requires a physical device with a Secure Enclave."
        case .appAttestBypassIsMissing:
            return "AIProxy - You are running on a simulator without setting the AIPROXY_APP_ATTEST_BYPASS env variable. Copy the bypass token from the App Attest tab of the AIProxy dashboard into your Xcode scheme's environment variables."
        case .appAttestRequiresServiceURL:
            return "AIProxy - App Attest needs the AIProxy app: pass the appURL shown on the App Attest tab of the dashboard (https://api.aiproxy.com/<app>) to AIProxy.configure, and the serviceURL shown for each service when creating it. The legacy partial-key-only initializers cannot use App Attest."
        case .appAttestKeyInvalidated:
            return "AIProxy - Apple reported this device's App Attest key as invalid and a replacement could not be attested. Please check your network connection and try again."
        case .appAttestRegistrationFailed(statusCode: let statusCode, responseBody: let responseBody, retryAfter: _):
            return "AIProxy - App Attest registration failed with status code \(statusCode) and response body: \(responseBody)"
        case .appAttestRegistrationBackingOff(until: let until, cause: let cause):
            return "AIProxy - App Attest registration is backing off until \(until) after a failure: \(cause)"
        case .appAttestMalformedResponse(route: let route):
            return "AIProxy - The App Attest \(route) response could not be parsed."
        case .appAttestKeychainError(status: let status):
            return "AIProxy - Could not read or write the App Attest key ID in the Keychain (OSStatus \(status))."
        }

    }
}

