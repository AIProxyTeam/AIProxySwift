//
//  OpenAIRealtimeInputAudioBufferAppend.swift
//
//
//  Created by Lou Zell on 10/30/24.
//

import Foundation

nonisolated public struct OpenAIRealtimeInputAudioBufferAppend: Encodable {
    public let type = "input_audio_buffer.append"

    /// base64 encoded PCM16 data
    public let audio: String

    public init(audio: String) {
        self.audio = audio
    }
}
