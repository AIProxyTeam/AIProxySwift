//
//  OpenAIUtils.swift
//
//
//  Created by Lou Zell on 7/9/24.
//

import AVFoundation
import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AudioToolbox)
import AudioToolbox
#endif

#if canImport(StoreKit)
import StoreKit
#endif

import Network

enum AIProxyUtils {

    nonisolated static let directURLSession = URLSession(
        configuration: .ephemeral,
        delegate: DirectURLSessionDataDelegate(),
        delegateQueue: nil
    )

    nonisolated static func proxiedURLSession() -> URLSession {
        if AIProxy.resolveDNSOverTLS {
            let host = NWEndpoint.hostPort(host: "one.one.one.one", port: 853)
            let endpoints: [NWEndpoint] = [
                .hostPort(host: "1.1.1.1", port: 853),
                .hostPort(host: "1.0.0.1", port: 853),
                .hostPort(host: "2606:4700:4700::1111", port: 853),
                .hostPort(host: "2606:4700:4700::1001", port: 853)
            ]
            NWParameters.PrivacyContext.default.requireEncryptedNameResolution(
                true,
                fallbackResolver: .tls(host, serverAddresses: endpoints)
            )
        }
        return AIProxyURLSession.urlSession
    }

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    nonisolated static func encodeImageAsJpeg(
        _ image: NSImage,
        _ compressionQuality: CGFloat
    ) -> Data? {
        return image.jpegData(compressionQuality: compressionQuality)
    }

    nonisolated static func encodeImageAsURL(
        _ image: NSImage,
        _ compressionQuality: CGFloat
    ) -> URL? {
        guard let jpegData = self.encodeImageAsJpeg(image, compressionQuality) else {
            return nil
        }
        return URL(string: "data:image/jpeg;base64,\(jpegData.base64EncodedString())")
    }

#elseif canImport(UIKit)
    nonisolated static func encodeImageAsJpeg(
        _ image: UIImage,
        _ compressionQuality: CGFloat
    ) -> Data? {
        return image.jpegData(compressionQuality: compressionQuality)
    }

    nonisolated static func encodeImageAsURL(
        _ image: UIImage,
        _ compressionQuality: CGFloat
    ) -> URL? {
        guard let jpegData = self.encodeImageAsJpeg(image, compressionQuality) else {
            return nil
        }
        return URL(string: "data:image/jpeg;base64,\(jpegData.base64EncodedString())")
    }
#endif

    nonisolated static func metadataHeader(withBodySize bodySize: Int?) async -> String {
        let ri = await RuntimeInfo.getCurrent()
        let fields: [String] = [
            "v4",
            ri.bundleID,
            ri.appVersion,
            AIProxy.sdkVersion,
            String(Date().timeIntervalSince1970),
            ri.systemName,
            ri.osVersion,
            ri.deviceModel,
            String(bodySize ?? 0)
        ]
        return fields.joined(separator: "|")
    }

    #if os(macOS)
    nonisolated static func getDefaultAudioInputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID()
        var propSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let err = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propSize,
            &deviceID
        )
        guard err == noErr else {
            logIf(.error)?.error("Could not query for default audio input device")
            return nil
        }
        return deviceID
    }

    nonisolated static func getAllAudioInputDevices() -> [AudioDeviceID] {
        var propSize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var err = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propSize
        )
        guard err == noErr else {
            logIf(.error)?.error("Could not set propSize, needed for querying all audio devices")
            return []
        }

        var devices = [AudioDeviceID](
            repeating: 0,
            count: Int(propSize / UInt32(MemoryLayout<AudioDeviceID>.size))
        )
        err = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propSize,
            &devices
        )
        guard err == noErr else {
            logIf(.error)?.error("Could not query for all audio devices")
            return []
        }
        return devices
    }
    #endif

    nonisolated static var headphonesConnected: Bool {
        #if os(macOS)
        return audioToolboxHeadphonesConnected()
        #else
        return audioSessionHeadphonesConnected()
        #endif
    }

    @AIProxyActor static func getAppTransactionID() async -> String? {
        #if compiler(<6.1.2)
        return nil
        #else
        guard #available(iOS 16.0, watchOS 9.0, macOS 13.0, tvOS 16.0, visionOS 1.0, *) else {
            return nil
        }

        // Apple's docstring on `shared` states:
        // If your app fails to get an AppTransaction by accessing the shared property, see refresh().
        // Source: https://developer.apple.com/documentation/storekit/apptransaction/shared
        var appTransaction: VerificationResult<AppTransaction>?
        do {
            appTransaction = try await AppTransaction.shared
        } catch {
            appTransaction = try? await AppTransaction.refresh()
        }

        guard let appTransaction = appTransaction,
              case .verified(let verifiedAppTransaction) = appTransaction else {
            logIf(.info)?.info("AIProxy: Couldn't get a verified app store receipt. Unable to use appTransactionID as a client identifier")
            return nil
        }

        let transactionID = verifiedAppTransaction.appTransactionID
        guard transactionID != "0" && transactionID != "" else {
            logIf(.info)?.info("AIProxy: Storekit's appTransactionID is zero or empty, ignoring it")
            return nil
        }

        return transactionID
        #endif
    }

    /// Parses the project and service from the client's `serviceURL`
    nonisolated static func serviceIdentifiers(
        from serviceURL: String
    ) throws -> (project: String, service: String) {
        guard let components = URLComponents(string: serviceURL) else {
            throw AIProxyError.assertion("Could not parse the AIProxy serviceURL")
        }

        let pathComponents = components.path.split(separator: "/", omittingEmptySubsequences: true)
        guard pathComponents.count == 2 else {
            throw AIProxyError.assertion(
                "Expected the AIProxy serviceURL path to contain a project and service identifier"
            )
        }

        return (String(pathComponents[0]), String(pathComponents[1]))
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
extension NSImage {
    nonisolated func jpegData(compressionQuality: CGFloat = 1.0) -> Data? {
        guard let tiffData = self.tiffRepresentation else {
            return nil
        }
        guard let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        let jpegData = bitmapImage.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
        return jpegData
    }
}
#endif


#if !os(macOS)
nonisolated private func audioSessionHeadphonesConnected() -> Bool {
    let session = AVAudioSession.sharedInstance()
    let outputs = session.currentRoute.outputs

    for output in outputs {
        if output.portType == .headphones ||
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothLE ||
            output.portType == .bluetoothHFP {
            return true
        }
    }
    return false
}
#endif


#if os(macOS)
nonisolated private func audioToolboxHeadphonesConnected() -> Bool {
    for deviceID in AIProxyUtils.getAllAudioInputDevices() {
        if isHeadphoneDevice(deviceID: deviceID) && isDeviceAlive(deviceID: deviceID) {
            return true
        }
    }
    return false
}

nonisolated private func isHeadphoneDevice(deviceID: AudioDeviceID) -> Bool {
    guard hasOutputStreams(deviceID: deviceID) else {
        return false
    }

    let transportType = getTransportType(deviceID: deviceID)

    if [
        kAudioDeviceTransportTypeBluetooth,
        kAudioDeviceTransportTypeBluetoothLE,
        kAudioDeviceTransportTypeUSB
    ].contains(transportType) {
        return true
    }

    // For built-in devices, we need to check the device name or UID
    if transportType == kAudioDeviceTransportTypeBuiltIn {
        return isBuiltInHeadphonePort(deviceID: deviceID)
    }

    return false
}

nonisolated private func getTransportType(deviceID: AudioDeviceID) -> UInt32 {
    var transportType = UInt32(0)
    var propSize = UInt32(MemoryLayout<UInt32>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyTransportType,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    let err = AudioObjectGetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        &propSize,
        &transportType
    )
    guard err == noErr else {
        logIf(.error)?.error("Could not get transport type for audio device")
        return 0
    }
    return transportType
}

nonisolated private func isBuiltInHeadphonePort(deviceID: AudioDeviceID) -> Bool {
    var deviceUID: CFString? = nil
    var propSize = UInt32(MemoryLayout<CFString>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    let err = withUnsafeMutablePointer(to: &deviceUID) { ptr -> OSStatus in
        return AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propSize,
            ptr
        )
    }

    guard err == noErr, let uidString = deviceUID as? String else {
        logIf(.error)?.error("Could not get mic's uidString from CFString")
        return false
    }

    let retval = ["headphone", "lineout"].contains { uidString.lowercased().contains($0) }
    return retval
}

nonisolated private func hasOutputStreams(deviceID: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    var propSize: UInt32 = 0
    let err = AudioObjectGetPropertyDataSize(
        deviceID,
        &address,
        0,
        nil,
        &propSize
    )
    guard err == noErr else {
        logIf(.error)?.error("Could not check for output streams on audio device")
        return false
    }
    return propSize > 0
}

nonisolated private func isDeviceAlive(deviceID: AudioDeviceID) -> Bool {
    var isAlive: UInt32 = 0
    var propSize = UInt32(MemoryLayout<UInt32>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsAlive,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    let err = AudioObjectGetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        &propSize,
        &isAlive
    )
    guard err == noErr else {
        logIf(.error)?.error("Could not check if the audio input is alive")
        return false
    }
    return isAlive != 0
}
#endif
