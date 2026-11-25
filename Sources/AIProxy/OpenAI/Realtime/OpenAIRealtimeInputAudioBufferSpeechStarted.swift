//
//  OpenAIRealtimeInputAudioBufferSpeechStarted.swift
//
//
//  Created by Lou Zell on 11/4/24.
//

import Foundation

/// This is not actually used! I'm not using decodable for this event, just inspecting the 'type' string
/// This is sent from server to client when vad detects that speech started.
nonisolated public struct OpenAIRealtimeInputAudioBufferSpeechStarted: Decodable, Sendable {
    public let type = "input_audio_buffer.speech_started"
    public let audioStartMs: Int
    
    public init(audioStartMs: Int) {
        self.audioStartMs = audioStartMs
    }

    private enum CodingKeys: String, CodingKey {
        case audioStartMs = "audio_start_ms"
    }
}
