import AVFoundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public enum AIProxy {

    /// The current sdk version
    nonisolated public static let sdkVersion = "0.156.0"

    /// Configures the AIProxy SDK. Call this during app launch by adding an `init` to your SwiftUI MyApp.swift file, e.g.
    ///
    ///     import AIProxy
    ///
    ///     @main
    ///     struct MyApp: App {
    ///         init() {
    ///             AIProxy.configure(
    ///                 logLevel: .debug,
    ///                 printRequestBodies: true,
    ///                 printResponseBodies: true,
    ///                 resolveDNSOverTLS: true,
    ///                 useStableID: true
    ///             )
    ///         }
    ///         // ...
    ///     }
    ///
    /// Or in your UIKit app's applicationDidFinishLaunching:
    ///
    ///     import AIProxy
    ///
    ///     @UIApplicationMain
    ///     class AppDelegate: UIResponder, UIApplicationDelegate {
    ///
    ///          var window: UIWindow?
    ///
    ///          func application(_ application: UIApplication,
    ///                           didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///              AIProxy.configure(
    ///                  logLevel: .debug,
    ///                  printRequestBodies: true,
    ///                  printResponseBodies: true,
    ///                  resolveDNSOverTLS: true,
    ///                  useStableID: true
    ///              )
    ///              // ...
    ///              return true
    ///          }
    ///          // ...
    ///      }
    ///
    /// - Parameters:
    ///   - logLevel:            Sets the threshold severity of SDK logs that will be shown in the Xcode console.
    ///                          For the most verbose logging, set this to `.debug`
    ///
    ///   - printRequestBodies:  Print API request bodies to the Xcode console.
    ///                          Request bodies are logged at the `.debug` level, so if you would like to use this feature please also set `logLevel` to `.debug`
    ///
    ///   - printResponseBodies: Print API response bodies to the Xcode console.
    ///                          Response bodies are logged at the `.debug` level, so if you would like to use this feature please also set `logLevel` to `.debug`
    ///
    ///   - resolveDNSOverTLS:   Set this to true to perform DNS resolution over TLS using Cloudflare's resolver.
    ///                          The SDK defaults to true for this unless you explicitly set it to false here.
    ///                          It prevents your customer's ISP from snooping on or blocking requests to AIProxy.
    ///
    ///   - useStableID:         Set this to true to perform a best effort attempt to use the same anonymous ID in requests to AIProxy for an app store user across multiple devices.
    ///                          You must add the 'iCloud key-value storage' capability to use this:
    ///                              1. Tap on your project in Xcode's project tree
    ///                              2. Tap on your target in the sidebar
    ///                              3. Tap on Signing & Capabilities in the top nav
    ///                              4. Tap the plus sign next to 'Capability'
    ///                              5. Add iCloud
    ///                              6. Select the 'Key-value storage' service
    ///
    ///                          If possible, StoreKit's appTransactionID will be used as the stable ID.
    ///                          If the app store receipt cannot be verified then we fall back to a GUID synced across iCloud-backed keychain and UKVS.
    nonisolated public static func configure(
        logLevel: AIProxyLogLevel,
        printRequestBodies: Bool,
        printResponseBodies: Bool,
        resolveDNSOverTLS: Bool,
        useStableID: Bool
    ) {
        let previouslyUsingStableID = self.configuration?.useStableID ?? false
        AIProxyLogLevel.callerDesiredLogLevel = logLevel
        self.configuration = AIProxyConfiguration(
            resolveDNSOverTLS: resolveDNSOverTLS,
            printRequestBodies: printRequestBodies,
            printResponseBodies: printResponseBodies,
            useStableID: useStableID
        )
        if useStableID && !previouslyUsingStableID {
            Task { @AIProxyActor in
                if let newStableID = await AIProxyConfiguration.getStableIdentifier() {
                    self.configuration?.stableID = newStableID
                }
            }
        }
    }

    /// This must only be accessed through `ProtectedPropertyQueue.configuration`.
    nonisolated(unsafe) static private var _configuration: AIProxyConfiguration?
    nonisolated static var configuration: AIProxyConfiguration? {
        get {
            ProtectedPropertyQueue.configuration.sync { self._configuration }
        }
        set {
            ProtectedPropertyQueue.configuration.async(flags: .barrier) { self._configuration = newValue }
        }
    }

    /// Flag to use DNS over TLS.
    /// See this Apple Developer forum post for motivation: https://developer.apple.com/forums/thread/780602
    /// Note that this does add some latency to your first request.
    /// In my testing, at least for my location in SF, it added about 50ms.
    /// You can test for yourself with these commands (the first is similar to flipping this flag to true):
    ///
    ///    kdig @1.1.1.1 api.aiproxy.com +tls +noall +stats
    ///
    /// Compare to udp perf using your default resolver:
    ///
    ///    kdig api.aiproxy.com +noall +stats
    ///
    /// Or using cloudflare's resolver
    ///
    ///    kdig @1.1.1.1 api.aiproxy.com +noall +stats
    nonisolated public static var resolveDNSOverTLS: Bool {
        self.configuration?.resolveDNSOverTLS ?? false
    }

    nonisolated public static var stableID: String? {
        self.configuration?.stableID
    }

    nonisolated public static var printRequestBodies: Bool {
        self.configuration?.printRequestBodies ?? false
    }

    nonisolated public static var printResponseBodies: Bool {
        self.configuration?.printResponseBodies ?? false
    }

    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your provider's key.
    ///     AIProxy takes your key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to your provider.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your provider's key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    ///   - proxyPath: The path that you want to forward the request onto. For example, if you are trying to reach
    ///     api.example.com/v1/chat/completions, then you would set the proxyPath to `/v1/chat/completions`
    ///
    ///   - body: An optional request body
    ///
    ///   - verb: The HTTP verb to use for this request. If you leave the default selection of 'automatic', then requests that
    ///     contain a body will default to `POST` while requests with no body will default to `GET`
    ///
    ///   - contentType: The optional content type of the request body.
    ///
    ///   - headers: An optional set of additional headers to include in the request.
    ///
    /// - Returns: A request containing all headers that AIProxy expects. The request is ready to be used with a url session
    ///            that you create with `AIProxy.session()`
    nonisolated public static func request(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil,
        proxyPath: String,
        body: Data? = nil,
        verb: AIProxyHTTPVerb = .automatic,
        headers: [String: String] = [:]
    ) async throws -> URLRequest {
        return try await AIProxyURLRequest.create(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID,
            proxyPath: proxyPath,
            body: body,
            verb: verb,
            secondsToWait: 60,
            additionalHeaders: headers
        )
    }

    /// Returns a URLSession for communication with AIProxy.
    nonisolated public static func session() -> URLSession {
        return AIProxyURLSession.urlSession
    }

    /// AIProxy's OpenAI service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your OpenAI key.
    ///     AIProxy takes your OpenAI key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to OpenAI.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your OpenAI key.
    ///     This argument is required for keys that you submitted after July 22nd, 2024. If you are an existing customer that
    ///     configured your AIProxy project before July 22nd, you may continue to leave this blank.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    ///   - requestFormat: If you are sending requests to your own Azure deployment, set this to `.azureDeployment`.
    ///                    Otherwise, you may leave this set to its default value of `.standard`.
    ///
    /// - Returns: An instance of OpenAIService configured and ready to make requests
    nonisolated public static func openAIService(
        partialKey: String,
        serviceURL: String? = nil,
        clientID: String? = nil,
        requestFormat: OpenAIRequestFormat = .standard
    ) -> OpenAIService {
        return OpenAIProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID,
            requestFormat: requestFormat
        )
    }

    /// Service that makes request directly to OpenAI. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your OpenAI API key
    ///   - baseURL: Optional base URL for the API requests
    ///   - requestFormat: If you are sending requests to your own Azure deployment, set this to `.azureDeployment`.
    ///                   Otherwise, you may leave this set to its default value of `.standard`
    /// - Returns: An instance of OpenAIService configured and ready to make requests
    nonisolated public static func openAIDirectService(
        unprotectedAPIKey: String,
        baseURL: String? = nil,
        requestFormat: OpenAIRequestFormat = .standard
    ) -> OpenAIService {
        return OpenAIDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            requestFormat: requestFormat,
            baseURL: baseURL
        )
    }

    /// AIProxy's Gemini service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your Gemini key.
    ///     AIProxy takes your Gemini key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to Gemini.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your Gemini key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of GeminiService configured and ready to make requests
    nonisolated public static func geminiService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> GeminiService {
        return GeminiProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to Gemini. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your Gemini API key
    /// - Returns: An instance of  GeminiService configured and ready to make requests
    nonisolated public static func geminiDirectService(
        unprotectedAPIKey: String
    ) -> GeminiService {
        return GeminiDirectService(
            unprotectedAPIKey: unprotectedAPIKey
        )
    }

    /// AIProxy's Anthropic service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your Anthropic key.
    ///     AIProxy takes your Anthropic key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to Anthropic.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your Anthropic key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of AnthropicService configured and ready to make requests
    nonisolated public static func anthropicService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> AnthropicService {
        return AnthropicProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to Anthropic. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your Anthropic API key
    /// - Returns: An instance of AnthropicService configured and ready to make requests
    nonisolated public static func anthropicDirectService(
        unprotectedAPIKey: String,
        baseURL: String? = nil
    ) -> AnthropicService {
        return AnthropicDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            baseURL: baseURL
        )
    }

    /// AIProxy's Stability.ai service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your Stability.ai key.
    ///     AIProxy takes your Stability.ai key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to Stability.ai.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your Stability.ai key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of StabilityAIService configured and ready to make requests
    nonisolated public static func stabilityAIService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> StabilityAIService {
        return StabilityAIProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to StabilityAI. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your StabilityAI API key
    /// - Returns: An instance of StabilityAIService configured and ready to make requests
    nonisolated public static func stabilityAIDirectService(
        unprotectedAPIKey: String
    ) -> StabilityAIService {
        return StabilityAIDirectService(
            unprotectedAPIKey: unprotectedAPIKey
        )
    }

    /// AIProxy's DeepL service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your DeepL key.
    ///     AIProxy takes your DeepL key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to DeepL.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your DeepL key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of DeepLService configured and ready to make requests
    nonisolated public static func deepLService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> DeepLService {
        return DeepLProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to DeepL. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your DeepL API key
    ///   - accountType: Free or paid
    /// - Returns: An instance of DeepLService configured and ready to make requests
    nonisolated public static func deepLDirectService(
        unprotectedAPIKey: String,
        accountType: DeepLAccountType
    ) -> DeepLService {
        return DeepLDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            accountType: accountType
        )
    }

    /// AIProxy's TogetherAI service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your TogetherAI key.
    ///     AIProxy takes your TogetherAI key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to TogetherAI.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your TogetherAI key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of TogetherAIService configured and ready to make requests
    nonisolated public static func togetherAIService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> TogetherAIService {
        return TogetherAIProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to TogetherAI. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your TogetherAI API key
    /// - Returns: An instance of TogetherAIService configured and ready to make requests
    nonisolated public static func togetherAIDirectService(
        unprotectedAPIKey: String
    ) -> TogetherAIService {
        return TogetherAIDirectService(
            unprotectedAPIKey: unprotectedAPIKey
        )
    }

    /// AIProxy's Replicate service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your Replicate key.
    ///     AIProxy takes your Replicate key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to Replicate.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your Replicate key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of ReplicateService configured and ready to make requests
    nonisolated public static func replicateService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> ReplicateService {
        return ReplicateProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to Replicate. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your Replicate API key
    /// - Returns: An instance of ReplicateService configured and ready to make requests
    nonisolated public static func replicateDirectService(
        unprotectedAPIKey: String
    ) -> ReplicateService {
        return ReplicateDirectService(
            unprotectedAPIKey: unprotectedAPIKey
        )
    }

    /// AIProxy's ElevenLabs service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your ElevenLabs key.
    ///     AIProxy takes your ElevenLabs key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to ElevenLabs.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your ElevenLabs key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of ElevenLabsService configured and ready to make requests
    nonisolated public static func elevenLabsService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> ElevenLabsService {
        return ElevenLabsProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to ElevenLabs. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your ElevenLabs API key
    /// - Returns: An instance of  ElevenLabsService configured and ready to make requests
    nonisolated public static func elevenLabsDirectService(
        unprotectedAPIKey: String
    ) -> ElevenLabsService {
        return ElevenLabsDirectService(
            unprotectedAPIKey: unprotectedAPIKey
        )
    }

    /// AIProxy's Fal service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your Fal key.
    ///     AIProxy takes your Fal key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to Fal.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your Fal key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of FalService configured and ready to make requests
    nonisolated public static func falService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> FalService {
        return FalProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to ElevenLabs. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your ElevenLabs API key
    /// - Returns: An instance of  ElevenLabsService configured and ready to make requests
    nonisolated public static func falDirectService(
        unprotectedAPIKey: String
    ) -> FalService {
        return FalDirectService(
            unprotectedAPIKey: unprotectedAPIKey
        )
    }

    /// AIProxy's Groq service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your Groq key.
    ///     AIProxy takes your Groq key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to Groq.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your Groq key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of GroqService configured and ready to make requests
    nonisolated public static func groqService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> GroqService {
        return GroqProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to Groq. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your Groq API key
    /// - Returns: An instance of  GroqService configured and ready to make requests
    nonisolated public static func groqDirectService(
        unprotectedAPIKey: String,
        baseURL: String? = nil
    ) -> GroqService {
        return GroqDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            baseURL: baseURL
        )
    }

    /// AIProxy's Perplexity service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your Perplexity key.
    ///     AIProxy takes your Perplexity key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to Perplexity.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your Perplexity key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of PerplexityService configured and ready to make requests
    nonisolated public static func perplexityService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> PerplexityService {
        return PerplexityProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to Perplexity. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your Perplexity API key
    /// - Returns: An instance of  PerplexityService configured and ready to make requests
    nonisolated public static func perplexityDirectService(
        unprotectedAPIKey: String
    ) -> PerplexityService {
        return PerplexityDirectService(
            unprotectedAPIKey: unprotectedAPIKey
        )
    }

    /// AIProxy's Mistral service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your Mistral key.
    ///     AIProxy takes your Mistral key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to Mistral.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your Mistral key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of MistralService configured and ready to make requests
    nonisolated public static func mistralService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> MistralService {
        return MistralProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to Mistral. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your Mistral API key
    ///   - baseURL: An optional base URL to use for requests. If not provided, the default Mistral API
    ///     base URL is used (`https://api.mistral.ai`).
    /// - Returns: An instance of MistralService configured and ready to make requests
    nonisolated public static func mistralDirectService(
        unprotectedAPIKey: String,
        baseURL: String? = nil
    ) -> MistralService {
        return MistralDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            baseURL: baseURL
        )
    }

    /// AIProxy's EachAI service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your EachAI key.
    ///     AIProxy takes your EachAI key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to EachAI.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your EachAI key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of EachAIService configured and ready to make requests
    nonisolated public static func eachAIService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> EachAIService {
        return EachAIProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to EachAI. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your EachAI API key
    /// - Returns: An instance of  EachAI configured and ready to make requests
    nonisolated public static func eachAIDirectService(
        unprotectedAPIKey: String
    ) -> EachAIService {
        return EachAIDirectService(
            unprotectedAPIKey: unprotectedAPIKey
        )
    }

    /// AIProxy's OpenRouter service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your OpenRouter key.
    ///     AIProxy takes your OpenRouter key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to OpenRouter.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your OpenRouter key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of OpenRouterService configured and ready to make requests
    nonisolated public static func openRouterService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> OpenRouterService {
        return OpenRouterProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to OpenRouter. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your OpenRouter API key
    /// - Returns: An instance of  OpenRouter configured and ready to make requests
    nonisolated public static func openRouterDirectService(
        unprotectedAPIKey: String,
        baseURL: String? = nil
    ) -> OpenRouterService {
        return OpenRouterDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            baseURL: baseURL
        )
    }

    /// AIProxy's DeepSeek service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your DeepSeek key.
    ///     AIProxy takes your DeepSeek key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to DeepSeek.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your DeepSeek key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of DeepSeekService configured and ready to make requests
    nonisolated public static func deepSeekService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> DeepSeekService {
        return DeepSeekProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to DeepSeek. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your DeepSeek API key
    /// - Returns: An instance of  DeepSeek configured and ready to make requests
    nonisolated public static func deepSeekDirectService(
        unprotectedAPIKey: String,
        baseURL: String? = nil
    ) -> DeepSeekService {
        return DeepSeekDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            baseURL: baseURL
        )
    }

    /// AIProxy's FireworksAI service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your FireworksAI key.
    ///     AIProxy takes your FireworksAI key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to FireworksAI.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your FireworksAI key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of FireworksAIService configured and ready to make requests
    nonisolated public static func fireworksAIService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> FireworksAIService {
        return FireworksAIProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to FireworksAI. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your FireworksAI API key
    /// - Returns: An instance of  FireworksAI configured and ready to make requests
    nonisolated public static func fireworksAIDirectService(
        unprotectedAPIKey: String
    ) -> FireworksAIService {
        return FireworksAIDirectService(
            unprotectedAPIKey: unprotectedAPIKey
        )
    }

    /// AIProxy's Brave service
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key is displayed in the AIProxy dashboard when you submit your Brave key.
    ///     AIProxy takes your Brave key, encrypts it, and stores part of the result on our servers. The part that you include
    ///     here is the other part. Both pieces are needed to decrypt your key and fulfill the request to Brave.
    ///
    ///   - serviceURL: The service URL is displayed in the AIProxy dashboard when you submit your Brave key.
    ///
    ///   - clientID: An optional clientID to attribute requests to specific users or devices. It is OK to leave this blank for
    ///     most applications. You would set this if you already have an analytics system, and you'd like to annotate AIProxy
    ///     requests with IDs that are known to other parts of your system.
    ///
    ///     If you do not supply your own clientID, the internals of this lib will generate UUIDs for you. The default UUIDs are
    ///     persistent on macOS and can be accurately used to attribute all requests to the same device. The default UUIDs
    ///     on iOS are pesistent until the end user chooses to rotate their vendor identification number.
    ///
    /// - Returns: An instance of BraveService configured and ready to make requests
    nonisolated public static func braveService(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) -> BraveService {
        return BraveProxiedService(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID
        )
    }

    /// Service that makes request directly to Brave. No protections are built-in for this service.
    /// Please only use this for BYOK use cases.
    ///
    /// - Parameters:
    ///   - unprotectedAPIKey: Your Brave API key
    /// - Returns: An instance of  Brave configured and ready to make requests
    nonisolated public static func braveDirectService(
        unprotectedAPIKey: String
    ) -> BraveService {
        return BraveDirectService(
            unprotectedAPIKey: unprotectedAPIKey
        )
    }

    /// Returns the authentication and routing metadata needed to send an existing gRPC call through AIProxy.
    ///
    /// Add the returned key-value pairs to the metadata on your gRPC call. Your gRPC client remains responsible
    /// for the transport, method path, serialization, and response handling.
    ///
    /// - Parameters:
    ///   - partialKey: Your partial key from the AIProxy developer dashboard.
    ///   - serviceURL: Your service URL from the AIProxy developer dashboard.
    ///   - clientID: An optional client ID used to attribute requests to a specific user or device.
    /// - Returns: The metadata fields expected by the AIProxy gRPC endpoint.
    nonisolated public static func grpcMetadata(
        partialKey: String,
        serviceURL: String,
        clientID: String? = nil
    ) async throws -> [String: String] {
        let identifiers = try AIProxyUtils.serviceIdentifiers(from: serviceURL)
        let request = try await self.request(
            partialKey: partialKey,
            serviceURL: serviceURL,
            clientID: clientID,
            proxyPath: "/"
        )

        var metadata = (request.allHTTPHeaderFields ?? [:]).reduce(into: [String: String]()) {
            $0[$1.key.lowercased()] = $1.value
        }
        metadata["aiproxy-project"] = identifiers.project
        metadata["aiproxy-service"] = identifiers.service
        return metadata.filter { $0.key.hasPrefix("aiproxy-") }
    }

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    nonisolated public static func encodeImageAsJpeg(
        image: NSImage,
        compressionQuality: CGFloat /* = 1.0 */
    ) -> Data? {
        return AIProxyUtils.encodeImageAsJpeg(image, compressionQuality)
    }

    @available(*, deprecated, message: "This function is deprecated. Use AIProxy.encodeImageAsURL instead.")
    nonisolated public static func openAIEncodedImage(
        image: NSImage,
        compressionQuality: CGFloat /* = 1.0 */
    ) -> URL? {
        return AIProxyUtils.encodeImageAsURL(image, compressionQuality)
    }

    nonisolated public static func encodeImageAsURL(
        image: NSImage,
        compressionQuality: CGFloat /* = 1.0 */
    ) -> URL? {
        return AIProxyUtils.encodeImageAsURL(image, compressionQuality)
    }

#elseif canImport(UIKit)
    nonisolated public static func encodeImageAsJpeg(
        image: UIImage,
        compressionQuality: CGFloat /* = 1.0 */
    ) -> Data? {
        return AIProxyUtils.encodeImageAsJpeg(image, compressionQuality)
    }

    @available(*, deprecated, message: "This function is deprecated. Use AIProxy.encodeImageAsURL instead.")
    nonisolated public static func openAIEncodedImage(
        image: UIImage,
        compressionQuality: CGFloat /* = 1.0 */
    ) -> URL? {
        return AIProxyUtils.encodeImageAsURL(image, compressionQuality)
    }

    nonisolated public static func encodeImageAsURL(
        image: UIImage,
        compressionQuality: CGFloat /* = 1.0 */
    ) -> URL? {
        return AIProxyUtils.encodeImageAsURL(image, compressionQuality)
    }
#endif

    @available(*, deprecated, message: "Use AIProxy.configure and pass true for useStableID")
    nonisolated public static func getStableIdentifier() async -> String? {
        return await AIProxyConfiguration.getStableIdentifier()
    }

    nonisolated public static func base64EncodeAudioPCMBuffer(from buffer: AVAudioPCMBuffer) -> String? {
        guard buffer.format.channelCount == 1 else {
            logIf(.error)?.error("This encoding routine assumes a single channel")
            return nil
        }

        guard let audioBufferPtr = buffer.audioBufferList.pointee.mBuffers.mData else {
            logIf(.error)?.error("No audio buffer list available to encode")
            return nil
        }

        let audioBufferLenth = Int(buffer.audioBufferList.pointee.mBuffers.mDataByteSize)
        let data = Data(bytes: audioBufferPtr, count: audioBufferLenth).base64EncodedString()
        return data
    }
}
