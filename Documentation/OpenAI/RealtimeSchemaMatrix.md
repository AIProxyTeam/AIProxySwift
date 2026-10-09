# Realtime API Schema Matrix

This matrix maps the current OpenAI Realtime `session.update.session` and `response.create.response`
fields to AIProxySwift types and wire encoding behavior.

Reference: https://developers.openai.com/api/reference/resources/realtime

## Shared Realtime Session

These fields are used by Performance Realtime models, such as `gpt-realtime-1.5`, and are also used
by Realtime Reasoning models.

| Wire field | AIProxySwift API | Wire shape emitted |
| --- | --- | --- |
| `type` | `OpenAIRealtimeSessionConfiguration.type` | string |
| `include` | `OpenAIRealtimeSessionConfiguration.include` | string array |
| `model` | `OpenAIRealtimeSessionConfiguration.model` | string |
| `instructions` | `OpenAIRealtimeSessionConfiguration.instructions` | string |
| `max_output_tokens` | `OpenAIRealtimeSessionConfiguration.maxOutputTokens` | int or `"inf"` |
| `output_modalities` | `OpenAIRealtimeSessionConfiguration.outputModalities` | enum string array |
| `prompt` | `OpenAIRealtimeSessionConfiguration.prompt` | object (`id`, optional `variables`, optional `version`) |
| `tracing` | `OpenAIRealtimeSessionConfiguration.tracing` | string `"auto"` or object (`group_id`, `metadata`, `workflow_name`) |
| `truncation` | `OpenAIRealtimeSessionConfiguration.truncation` | string (`"auto"`/`"disabled"`) or retention-ratio object |
| `tools` | `OpenAIRealtimeSessionConfiguration.tools` | union array (`function`, `mcp`, `web_search`) |
| `tool_choice` | `OpenAIRealtimeSessionConfiguration.toolChoice` | string (`auto`/`none`/`required`) or typed selector object |
| `audio.input.format` | `OpenAIRealtimeSessionConfiguration.inputAudioFormat` | object (`type`, optional `rate`) |
| `audio.input.noise_reduction` | `OpenAIRealtimeSessionConfiguration.inputAudioNoiseReduction` | object (`type`) |
| `audio.input.transcription` | `OpenAIRealtimeSessionConfiguration.inputAudioTranscription` | object (`language`, `model`, `prompt`) |
| `audio.input.turn_detection` | `OpenAIRealtimeSessionConfiguration.turnDetection` | typed object union (`server_vad` / `semantic_vad`) |
| `audio.output.format` | `OpenAIRealtimeSessionConfiguration.outputAudioFormat` | object (`type`, optional `rate`) |
| `audio.output.speed` | `OpenAIRealtimeSessionConfiguration.speed` | number (range 0.25...1.5) |
| `audio.output.voice` | `OpenAIRealtimeSessionConfiguration.voice` | string or object (`id`) |

## Realtime Reasoning Session Fields

Realtime Reasoning models, such as `gpt-realtime-2`, add Reasoning-only fields to the same
`session.update.session` object.

| Wire field | AIProxySwift API | Wire shape emitted |
| --- | --- | --- |
| `reasoning` | `OpenAIRealtimeSessionConfiguration.reasoning` | object |
| `reasoning.effort` | `OpenAIRealtimeReasoning` | `minimal`, `low`, `medium`, `high`, or `xhigh` |
| `parallel_tool_calls` | `OpenAIRealtimeSessionConfiguration.parallelToolCalls` | boolean |

## Shared `response.create`

| Wire field | AIProxySwift API | Wire shape emitted |
| --- | --- | --- |
| `type` | `OpenAIRealtimeResponseCreate.type` | `"response.create"` |
| `event_id` | `OpenAIRealtimeResponseCreate.eventID` | optional string |
| `response.instructions` | `OpenAIRealtimeResponseCreate.Response.instructions` | optional string |
| `response.output_modalities` | `OpenAIRealtimeResponseCreate.Response.outputModalities` | optional enum string array |
| `response.tools` | `OpenAIRealtimeResponseCreate.Response.tools` | optional tool union array (`function`, `mcp`, `web_search`) |
| `response.tool_choice` | `OpenAIRealtimeResponseCreate.Response.toolChoice` | optional string/object union |

## Realtime Reasoning `response.create` Fields

| Wire field | AIProxySwift API | Wire shape emitted |
| --- | --- | --- |
| `response.reasoning` | `OpenAIRealtimeResponseCreate.Response.reasoning` | object |
| `response.reasoning.effort` | `OpenAIRealtimeReasoning` | `minimal`, `low`, `medium`, `high`, or `xhigh` |
| `response.parallel_tool_calls` | `OpenAIRealtimeResponseCreate.Response.parallelToolCalls` | boolean |

## Realtime Reasoning Output Phases

Realtime Reasoning output can be split into commentary and final answer phases.

| Wire field | AIProxySwift API | Wire shape decoded |
| --- | --- | --- |
| `response.output[].phase` | `OpenAIRealtimeResponseOutputItem.phase` | `commentary` or `final_answer` |
| `response.output_item.*.item.phase` | `OpenAIRealtimeResponseOutputItemAddedEvent.phase` / `OpenAIRealtimeResponseOutputItemDoneEvent.phase` | `commentary` or `final_answer` |
| `conversation.item.*.item.phase` | `OpenAIRealtimeConversationItemCreatedEvent.phase` | `commentary` or `final_answer` |

## `conversation.item.create`

Reference: https://platform.openai.com/docs/api-reference/realtime-client-events/conversation/item/create

| Wire field | AIProxySwift API | Wire shape emitted |
| --- | --- | --- |
| `type` | `OpenAIRealtimeConversationItemCreate.type` | `"conversation.item.create"` |
| `item.type` | `OpenAIRealtimeConversationItemCreate.Item` | `"message"`, `"function_call"`, `"function_call_output"` |
| `item.role` | `OpenAIRealtimeConversationItemCreate.Item.role` | optional string for message items |
| `item.content[].type` | `OpenAIRealtimeConversationItemCreate.Item.Content.type` | `input_text`, `output_text`, `input_audio`, `item_reference`, `input_image` |
| `item.content[].text` | `OpenAIRealtimeConversationItemCreate.Item.Content.text` | optional string |
| `item.content[].audio` | `OpenAIRealtimeConversationItemCreate.Item.Content.audio` | optional string |
| `item.content[].item_id` | `OpenAIRealtimeConversationItemCreate.Item.Content.itemID` | optional string |
| `item.call_id` | `OpenAIRealtimeConversationItemCreate.Item.callID` | optional string |
| `item.name` | `OpenAIRealtimeConversationItemCreate.Item.name` | optional string |
| `item.arguments` | `OpenAIRealtimeConversationItemCreate.Item.arguments` | optional string |
| `item.output` | `OpenAIRealtimeConversationItemCreate.Item.output` | optional string |
