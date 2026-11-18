//
//  AIProxyCertificatePinning.swift
//
//
//  Created by Lou Zell on 6/23/24.
//

import Foundation

/// ## About
/// Use this class in conjunction with a URLSession to adopt certificate pinning in your app.
/// Cert pinning greatly reduces the ability for an attacker to snoop on your traffic.
///
/// A common misunderstanding about https is that it's hard for an attacker to read your traffic.
/// Unfortunately, that is only true if you, as the developer, control both sides of the pipe.
/// As an app developer, this is almost never the case. You ship your apps to the app store, and
/// attackers install them. When an attacker has your app on hardware they control (e.g. an iPhone),
/// it is trivial for them to MITM your app and read encrypted traffic.
///
/// Certificate pinning adds an additional layer of security by only allowing the TLS handshake to
/// succeed if your app recognizes the public key from the other side. I have baked in several AIProxy
/// public keys to this implementation.
///
/// This also functions as a reference implementation for any other libraries that want to interact
/// with the aiproxy.pro service using certificate pinning.
///
/// ## Implementor's note, and a gotcha
/// Use an instance of this class as the delegate to URLSession. For example:
///
///     let mySession = URLSession(
///        configuration: .default,
///        delegate: AIProxyCertificatePinningDelegate(),
///        delegateQueue: nil
///     )
///
/// In a perfect world, this would be all that is required of you. In fact, it is all that is required to protect requests made
/// with `await mySession.data(for:)`, because Foundation calls `urlSession:didReceiveChallenge:`
/// internally. However, `await mySession.bytes(for:)` is not protected, which is rather odd. As a workaround,
/// change your callsites from:
///
///     await mySession.bytes(for: request)
///
/// to:
///
///     await mySession.bytes(
///         for: request,
///         delegate: mySession.delegate as? URLSessionTaskDelegate
///     )
///
/// If you encounter other calls in the wild that do not invoke `urlSession:didReceiveChallenge:` on this class,
/// please report them to me.
nonisolated public final class AIProxyCertificatePinningDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {

    private let pinnedPublicKeys: [Data]

    let configureRealtimeTrust: (@Sendable (SecTrust) -> OSStatus)?

    public override init() {
        self.pinnedPublicKeys = publicKeysAsData
        self.configureRealtimeTrust = nil
        super.init()
    }

    init(pinnedPublicKeys: [Data], configureRealtimeTrust: (@Sendable (SecTrust) -> OSStatus)? = nil) {
        self.pinnedPublicKeys = pinnedPublicKeys
        self.configureRealtimeTrust = configureRealtimeTrust
        super.init()
    }

    nonisolated(unsafe) private var _progressCallback: (@Sendable (Double) -> Void)?
    public var progressCallback: (@Sendable (Double) -> Void)? {
        get {
            ProtectedPropertyQueue.progressCallback.sync { self._progressCallback }
        }
        set {
            ProtectedPropertyQueue.progressCallback.async(flags: .barrier) { self._progressCallback = newValue }
        }
    }

    /// Why is this needed?
    /// For some streaming use cases, we don't want to always consume textual lines through the modern `asyncBytes.lines` helper.
    /// Some use cases require vending data as it arrives off the wire, such as streaming audio.
    /// Unfortunately, modern async/await URLSession APIs don't provide this functionality out of the box.
    /// This closure acts as a bridge to the legacy delegate-based URLSession partial data vendor.
    nonisolated(unsafe) private var _bridges: [URLSessionDataTask: URLSessionDataTaskBridge] = [:]
    var bridges: [URLSessionDataTask: URLSessionDataTaskBridge] {
        get {
            ProtectedPropertyQueue.urlSessionBridges.sync { self._bridges }
        }
    }

    func addBridge(for dataTask: URLSessionDataTask, box: URLSessionDataTaskBridge) {
        ProtectedPropertyQueue.urlSessionBridges.async(flags: .barrier) {
            self._bridges[dataTask] = box
        }
    }

    func removeBridge(for dataTask: URLSessionDataTask) {
        ProtectedPropertyQueue.urlSessionBridges.async(flags: .barrier) {
            self._bridges.removeValue(forKey: dataTask)
        }
    }

    // MARK: - URLSessionDelegate
    public func urlSession(
       _ session: URLSession,
       didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
       return self.answerChallenge(challenge)
    }

    // MARK: - URLSessionTaskDelegate
    public func urlSession(
      _ session: URLSession,
      task: URLSessionTask,
      didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
      return self.answerChallenge(challenge)
    }

   public func urlSession(
       _ session: URLSession,
       task: URLSessionTask,
       didSendBodyData bytesSent: Int64,
       totalBytesSent: Int64,
       totalBytesExpectedToSend: Int64
   ) {
       guard let progressCallback = progressCallback,
             totalBytesExpectedToSend > 0 else { return }
       let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
       progressCallback(progress)
   }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let dataTask = task as? URLSessionDataTask else {
            return
        }
        Task { @AIProxyActor in
            for completeCallback in self.bridges[dataTask]?.onComplete ?? [] {
                completeCallback(error)
            }
            self.removeBridge(for: dataTask)
        }
    }

    // MARK: - URLSessionDataDelegate conformance
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @Sendable @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        Task { @AIProxyActor in
            for responseCallback in self.bridges[dataTask]?.onResponse ?? [] {
                responseCallback(response)
            }
        }
        completionHandler(.allow)
    }

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        Task { @AIProxyActor in
            for dataCallback in self.bridges[dataTask]?.onData ?? [] {
                dataCallback(data)
            }
        }
    }

   // MARK: - Private
   private func answerChallenge(
      _ challenge: URLAuthenticationChallenge
   ) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
      guard let secTrust = challenge.protectionSpace.serverTrust else {
         logIf(.error)?.error("Could not access the server's security space")
         return (.cancelAuthenticationChallenge, nil)
      }

      guard matchesPinnedPublicKey(secTrust) else { return (.cancelAuthenticationChallenge, nil) }
      return (.useCredential, URLCredential(trust: secTrust))
   }

    /// Both Foundation challenges and native TLS connections use the same leaf public-key pins.
    func matchesPinnedPublicKey(_ trust: SecTrust) -> Bool {
        guard let certificate = getServerCert(secTrust: trust),
              let key = SecCertificateCopyKey(certificate),
              let data = SecKeyCopyExternalRepresentation(key, nil) as Data? else {
            logIf(.error)?.error("Could not extract the server's public key")
            return false
        }
        return pinnedPublicKeys.contains(data)
    }

    // MARK: - Deprecated
    @available(*, deprecated, message: "Please use the progressCallback setter directly, e.g. myDelegate.progressCallback = ...")
    public func setProgressCallback(_ callback: @escaping @Sendable (Double) -> Void) {
        self.progressCallback = callback
    }

    @available(*, deprecated, message: "Please use the progressCallback setter directly, e.g. myDelegate.progressCallback = nil")
    public func clearProgressCallback() {
        self.progressCallback = nil
    }
}

 // MARK: - Private
nonisolated private let publicKeysAsData: [Data] = {
     let newVal = publicKeysAsHex.map { publicKeyAsHex in
         let keyData = Data(publicKeyAsHex)

         let attributes: [String: Any] = [
             kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
             kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
             kSecAttrKeySizeInBits as String: 256
         ]

         var error: Unmanaged<CFError>?
         let publicKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error)!

         let localPublicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil)! as Data

         if let error = error {
             print("Failed to create public key: \(error.takeRetainedValue() as Error)")
             fatalError()
         }
         return localPublicKeyData
     }
     return newVal
 }()

nonisolated private let publicKeysAsHex: [[UInt8]] = [
     // live on api.aiproxy.com
     [
         0x04, 0x4a, 0x42, 0x12, 0xe7, 0xed, 0x36, 0xb4, 0xa9, 0x1f, 0x96, 0x7e, 0xcf, 0xbd, 0xe0,
         0x9d, 0xea, 0x4b, 0xfb, 0xaf, 0xe7, 0xc6, 0x93, 0xf0, 0xbf, 0x92, 0x0f, 0x12, 0x7a, 0x22,
         0x7d, 0x00, 0x77, 0x81, 0xa5, 0x06, 0x26, 0x06, 0x5c, 0x47, 0x8f, 0x57, 0xef, 0x41, 0x39,
         0x0b, 0x3d, 0x41, 0x72, 0x68, 0x33, 0x86, 0x69, 0x14, 0x2a, 0x36, 0x4d, 0x74, 0x7d, 0xbc,
         0x60, 0x91, 0xff, 0xcc, 0x29
     ],

     // live on api.aiproxy.pro
     [
         0x04, 0x25, 0xa2, 0xd1, 0x81, 0xc0, 0x38, 0xce, 0x57, 0xaa, 0x6e, 0xf0, 0x5a, 0xc3, 0x6a,
         0xa7, 0xc4, 0x69, 0x69, 0xcb, 0xeb, 0x24, 0xe5, 0x20, 0x7d, 0x06, 0xcb, 0xc7, 0x49, 0xd5,
         0x0c, 0xac, 0xe6, 0x96, 0xc5, 0xc9, 0x28, 0x00, 0x8e, 0x69, 0xff, 0x9d, 0x32, 0x01, 0x53,
         0x74, 0xab, 0xfd, 0x46, 0x03, 0x32, 0xed, 0x93, 0x7f, 0x0f, 0xe9, 0xd9, 0xc3, 0xaf, 0xe7,
         0xa5, 0xcb, 0xc1, 0x29, 0x35
     ],

     // live on beta-api.aiproxy.com
     [
         0x04, 0x17, 0x17, 0x1b, 0x5a, 0x2a, 0x6c, 0xc0, 0xcb, 0xd9, 0x1f, 0x87, 0xcc, 0xf8, 0x12,
         0x42, 0xd6, 0x73, 0x5f, 0x8e, 0x74, 0x0a, 0x3c, 0x03, 0x27, 0xae, 0x8f, 0xbc, 0xde, 0x21,
         0x49, 0xcd, 0xe1, 0x68, 0x53, 0x7d, 0xc5, 0x4e, 0xae, 0x81, 0xb5, 0x57, 0x92, 0x1c, 0xb3,
         0xe0, 0xf6, 0xf3, 0x83, 0xad, 0x5c, 0x8b, 0x1f, 0xa8, 0x03, 0xb3, 0xf1, 0xd6, 0xd6, 0x4d,
         0x76, 0x83, 0xaf, 0x2d, 0x8b
     ],

     // backup-EC-key-A.key
     [
         0x04, 0x2c, 0x25, 0x74, 0xbc, 0x7e, 0x18, 0x10, 0x27, 0xbd, 0x03, 0x56, 0x4a, 0x7b, 0x32,
         0xd2, 0xc1, 0xb0, 0x2e, 0x58, 0x85, 0x9a, 0xb0, 0x7d, 0xcd, 0x7e, 0x23, 0x33, 0x88, 0x2f,
         0xc0, 0xfe, 0xce, 0x2e, 0xbf, 0x36, 0x67, 0xc6, 0x81, 0xf6, 0x52, 0x2b, 0x9b, 0xaf, 0x97,
         0x3c, 0xac, 0x00, 0x39, 0xd8, 0xcc, 0x43, 0x6b, 0x1d, 0x65, 0xa5, 0xad, 0xd1, 0x57, 0x4b,
         0xad, 0xb1, 0x17, 0xd3, 0x10
     ],

     // backup-EC-key-B.key
     [
         0x04, 0x34, 0xae, 0x84, 0x94, 0xe9, 0x02, 0xf0, 0x78, 0x0e, 0xee, 0xe6, 0x4e, 0x39, 0x7f,
         0xb4, 0x84, 0xf6, 0xec, 0x55, 0x20, 0x0d, 0x36, 0xe9, 0xa6, 0x44, 0x6b, 0x9b, 0xe1, 0xef,
         0x19, 0xe7, 0x90, 0x5b, 0xf4, 0xa3, 0x29, 0xf3, 0x56, 0x7c, 0x60, 0x97, 0xf0, 0xc6, 0x61,
         0x83, 0x31, 0x5d, 0x2d, 0xc9, 0xcc, 0x40, 0x43, 0xad, 0x81, 0x63, 0xfd, 0xcf, 0xe2, 0x8e,
         0xfa, 0x07, 0x09, 0xf6, 0xf2
     ],

     // backup-EC-key-C.key
     [
         0x04, 0x84, 0x4e, 0x33, 0xc8, 0x60, 0xe7, 0x78, 0xaa, 0xa2, 0xb6, 0x0b, 0xcf, 0x7a, 0x52,
         0x43, 0xd1, 0x6d, 0x58, 0xff, 0x17, 0xb8, 0xea, 0x8a, 0x39, 0x53, 0xfb, 0x8b, 0x66, 0x7d,
         0x10, 0x39, 0x80, 0x2c, 0x8d, 0xc9, 0xc3, 0x34, 0x33, 0x98, 0x14, 0xeb, 0x88, 0x7b, 0xf5,
         0x4d, 0x1f, 0x07, 0xae, 0x6a, 0x02, 0x6b, 0xf5, 0x9b, 0xa8, 0xc6, 0x55, 0x5c, 0x27, 0xcd,
         0x1b, 0xc0, 0x27, 0x2d, 0x82
     ]

 ]

nonisolated private func getServerCert(secTrust: SecTrust) -> SecCertificate? {
    if #available(macOS 12.0, iOS 15.0, *) {
        guard let certs = SecTrustCopyCertificateChain(secTrust) as? [SecCertificate] else {
            return nil
        }
        return certs.first
    } else {
        return SecTrustGetCertificateAtIndex(secTrust, 0);
    }
}
