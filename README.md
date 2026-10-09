# About

Use this library to adopt AI APIs in your app. Swift clients for the following providers are
included:

- OpenAI
- Gemini
- Anthropic
- Stability AI
- DeepL
- Together AI
- Replicate
- ElevenLabs
- Fal
- Groq
- Perplexity
- Mistral
- EachAI
- OpenRouter
- DeepSeek
- Fireworks AI
- Brave

Your initialization code determines whether requests go straight to the provider or are
protected through the [AIProxy](https://www.aiproxy.com) backend.

We only recommend making requests straight to the provider during prototyping and for BYOK
use-cases.

Requests that are protected through AIProxy have five levels of security applied to keep your API
key secure and your AI bill predictable:

- Certificate pinning
- DeviceCheck verification
- Split key encryption
- Per user rate limits
- Per IP rate limits


# Installation

## Installation using Xcode

1. From within your Xcode project, select `File > Add Package Dependencies`

   <img src="https://github.com/lzell/AIProxySwift/assets/35940/d44698a0-34e6-434b-b501-390254a14439" alt="Add package dependencies" width="420">

2. Punch `github.com/lzell/aiproxyswift` into the package URL bar, and select the 'main' branch
   as the dependency rule. Alternatively, you can choose specific releases if you'd like to have finer control of when your dependency gets updated.

   <img src="https://github.com/lzell/AIProxySwift/assets/35940/fd76b588-5e19-4d4d-9748-8db3fd64df8e" alt="Set package rule" width="720">


## Installation using cocoapods

Add to your podfile:

    pod "AIProxy"

Then, from shell:

    pod install

## How to configure the package for use with AIProxy

We recommend using the AIProxy option `useStableID` to rate limit usage across an app store user's account on multiple devices.
To enable this, please first add support for iCloud's key-value storage:

1. Tap on your project in Xcode's project tree
2. Select your target in the secondary sidebar
3. Tap on Signing & Capabilities > Add Capability > iCloud
4. Check the 'Key-Value storage' checkbox

During your app's launch, call `AIProxy.configure`. Using this method, you can specify:

- the log level that you'd like to see in your Xcode console from the AIProxy lib
- whether to print request/response bodies to Xcode's console, which is useful for debugging or contributing to the library
- whether to resolve DNS queries [using Cloudflare's DoT](https://developers.cloudflare.com/1.1.1.1/encryption/dns-over-tls/) (recommended)
- whether to use stable identifiers as client IDs (recommended)

In a SwiftUI app, call `AIProxy.configure` in your app's composition root:

```swift
import AIProxy

@main
struct MyApp: App {
    init() {
        AIProxy.configure(
            logLevel: .debug,
            printRequestBodies: false,
            printResponseBodies: false,
            resolveDNSOverTLS: true,
            useStableID: true
        )
    }
    // ...
}
```

In a UIKit app, call `AIProxy.configure` in applicationDidFinishLaunching:

```swift
import AIProxy

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AIProxy.configure(
            logLevel: .debug,
            printRequestBodies: false,
            printResponseBodies: false,
            resolveDNSOverTLS: true,
            useStableID: true
        )
        // ...
        return true
    }
    // ...
}
```

## How to configure the AIProxy backend for use with your project

See the [AIProxy integration video](https://www.aiproxy.com/docs/integration-guide.html).
Note that this is not required if you are shipping an app where the customers provide their own
API keys (known as BYOK for "bring your own key").

If you are shipping an app using a personal or company API key, we highly recommend setting up
AIProxy as an alternative to building, monitoring, and maintaining your own backend.


# How to update the package

- If you set the dependency rule to `main` during installation, then you can ensure the package is
  up to date by right clicking on the package and selecting 'Update Package'

  <img src="https://github.com/lzell/AIProxySwift/assets/35940/aeee0ab2-362b-4995-b9ca-ff4e1dd04f47" alt="Update package version" width="720">


- If you selected a version-based rule, inspect the rule in the 'Package Dependencies' section
  of your project settings:

  <img src="https://github.com/lzell/AIProxySwift/assets/35940/ca788c4c-ac38-4d9d-bb4f-928a9487f6eb" alt="Update package rule" width="720">

  Once the rule is set to include the release version that you'd like to bring in, Xcode should
  update the package automatically. If it does not, right click on the package in the project
  tree and select 'Update Package'.


# How to contribute to the package

Your additions to AIProxySwift are welcome! I like to develop the library while working in an
app that depends on it:

1. Fork the repo
2. Clone your fork
3. Open your app in Xcode
4. Remove AIProxySwift from your app (since this is likely referencing a remote lib)
5. Go to `File > Add Package Dependencies`, and in the bottom left of that popup there is a button "Add local"
6. Tap "Add local" and then select the folder where you cloned AIProxySwift on your disk.

If you do that, then you can modify the source to AIProxySwift right from within your Xcode project for your app.
Once you're happy with your changes, open a PR here.

# Example usage

* [OpenAI](#openai)
* [Gemini](#gemini)
* [Anthropic](#anthropic)
* [Stability AI](#stability-ai)
* [DeepL](#deepl)
* [Together AI](#together-ai)
* [Replicate](#replicate)
* [ElevenLabs](#elevenlabs)
* [Fal](#fal)
* [Groq](#groq)
* [Perplexity](#perplexity)
* [Mistral](#mistral)
* [EachAI](#eachai)
* [OpenRouter](#openrouter)
* [DeepSeek](#deepseek)
* [Fireworks AI](#fireworks-ai)
* [Brave](#brave)
* [gRPC](#grpc)
* [Advanced Settings](#advanced-settings)


## OpenAI

### Get a non-streaming chat completion from OpenAI:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAIChatCompletionRequestBody(
        model: "gpt-5.2",
        messages: [
            .system(content: .text("You are a friendly assistant")),
            .user(content: .text("hello world"))
        ],
        reasoningEffort: .noReasoning
    )

    do {
        let response = try await openAIService.chatCompletionRequest(
            body: requestBody,
            secondsToWait: 120
        )
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create OpenAI chat completion: \(error)")
    }
```

### How to make a buffered chat completion to OpenAI with extended timeout

This is useful for `o1` and `o3` models.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAIChatCompletionRequestBody(
        model: "gpt-5.2",
        messages: [
          .developer(content: .text("You are a coding assistant")),
          .user(content: .text("Build a ruby service that writes latency stats to redis on each request"))
        ],
        reasoningEffort: .high
    )

    do {
        let response = try await openAIService.chatCompletionRequest(
            body: requestBody,
            secondsToWait: 300
        )
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch let err as URLError where err.code == URLError.timedOut {
        print("Request to OpenAI for a reasoning request timed out")
    } catch let err as URLError where [.notConnectedToInternet, .networkConnectionLost].contains(err.code) {
        print("Could not complete OpenAI reasoning request. Please check your internet connection")
    } catch {
        print("Could not complete OpenAI reasoning request: \(error)")
    }
```


### Get a streaming chat completion from OpenAI:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAIChatCompletionRequestBody(
        model: "gpt-5.2",
        messages: [.user(content: .text("hello world"))]
        reasoningEffort: .noReasoning
    )

    do {
        let stream = try await openAIService.streamingChatCompletionRequest(
            body: requestBody,
            secondsToWait: 60
        )
        for try await chunk in stream {
            print(chunk.choices.first?.delta.content ?? "")
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create OpenAI streaming chat completion: \(error)")
    }
```

### How to include history in chat completion requests to OpenAI

Use this approach to have a conversation with ChatGPT. All previous chat messages, whether
issued by the user or the assistant (chatGPT), are fed back into the model on each request.

As an alternative, you can use the new ChatGPT Responses API to hold the entire history by passing in the previousResponseId

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    // We'll start the conversation by asking about the color of a blackberry.
    // There is no prior history, so we only send up a single user message.
    //
    // You can optionally include a .system message to give the model
    // instructions on how it should behave.
    let userMessage1: OpenAIChatCompletionRequestBody.Message = .user(
        content: .text("What color is a blackberry?")
    )

    // Create the first chat completion.
    var completion1: OpenAIChatCompletionResponseBody? = nil
    do {
        completion1 = try await openAIService.chatCompletionRequest(body: .init(
            model: "gpt-5-mini",
            messages: [
                userMessage1
            ]
        ))
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not get first chat completion: \(error)")
    }

    // Get the contents of the model's first response:
    guard let assistantContent1 = completion1?.choices.first?.message.content else {
        print("Completion1: ChatGPT did not respond with any assistant content")
        return
    }
    print("Completion1: \(assistantContent1)")

    // Continue the conversation by asking about a strawberry.
    // If the history were absent from the request, ChatGPT would respond with general facts.
    // By including the history, the model continues the conversation, understanding that we
    // are specifically interested in the strawberry's color.
    let userMessage2: OpenAIChatCompletionRequestBody.Message = .user(
        content: .text("And a strawberry?")
    )

    // Create the second chat completion, note the `messages` array.
    var completion2: OpenAIChatCompletionResponseBody? = nil
    do {
        completion2 = try await openAIService.chatCompletionRequest(body: .init(
            model: "gpt-5-mini",
            messages: [
                userMessage1,
                .assistant(content: .text(assistantContent1)),
                userMessage2
            ]
        ))
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not get second chat completion: \(error)")
    }

    // Get the contents of the model's second response:
    guard let assistantContent2 = completion2?.choices.first?.message.content else {
        print("Completion2: ChatGPT did not respond with any assistant content")
        return
    }
    print("Completion2: \(assistantContent2)")
```

### Send a multi-modal chat completion request to OpenAI:

On macOS, use `NSImage(named:)` in place of `UIImage(named:)`


```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = UIImage(named: "myImage") else {
        print("Could not find an image named 'myImage' in your app assets")
        return
    }

    guard let imageURL = AIProxy.encodeImageAsURL(image: image, compressionQuality: 0.6) else {
        print("Could not encode image as data URL")
        return
    }

    do {
        let response = try await openAIService.chatCompletionRequest(body: .init(
            model: "gpt-5.2",
            messages: [
                .system(
                    content: .text("Tell me what you see")
                ),
                .user(
                    content: .parts(
                        [
                            .text("What do you see?"),
                            .imageURL(imageURL, detail: .auto)
                        ]
                    )
                )
            ]
        ))
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create OpenAI multi-modal chat completion: \(error)")
    }
```

### How to generate an image with DALLE

This snippet will print out the URL of an image generated with `dall-e-3`:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let response = try await openAIService.createImageRequest(
            body: .init(
                prompt: "a skier",
                model: .dallE3
            ),
            secondsToWait: 300
        )
        print(response.data.first?.url ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create an image with DALLE 3: \(error)")
    }
```

### How to generate an image with OpenAI's gpt-image-1

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let response = try await openAIService.createImageRequest(
            body: .init(
                prompt: "a skier",
                model: .gptImage1
            ),
            secondsToWait: 300
        )

        guard let base64Data = response.data.first?.b64JSON,
              let imageData = Data(base64Encoded: base64Data),
              let image = UIImage(data: imageData) else {
            print("Could not create a UIImage out of the base64 returned by OpenAI")
            return
        }

        // Do something with 'image'
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create OpenAI image generation: \(error)")
    }
```

### How to make a high fidelity image edit with OpenAI's gpt-image-1

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )
    let openAIService = getOpenAIService(config)

    guard let image = UIImage(named: "my-image") else {
        print("Could not find an image named 'my-image' in your app assets")
        return
    }

    guard let jpegData = AIProxy.encodeImageAsJpeg(image: image, compressionQuality: 0.5) else {
        print("Could not encode image as jpeg")
        return
    }

    let requestBody = OpenAICreateImageEditRequestBody(
        images: [.jpeg(jpegData)],
        prompt: "Change the coffee cup to red",
        inputFidelity: .high,
        model: .gptImage1
    )

    do {
        let response = try await openAIService.createImageEditRequest(
            body: requestBody,
            secondsToWait: 300
        )
        guard let base64Data = response.data.first?.b64JSON,
              let imageData = Data(base64Encoded: base64Data),
              let editedImage = UIImage(data: imageData) else {
            print("Could not create a UIImage out of the base64 returned by OpenAI")
            return
        }

        // Do something with 'editedImage' here

    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create OpenAI edit image generation: \(error)")
    }
```

### How to upload multiple images for use in an image edit with OpenAI's gpt-image-1

- This snippet uploads two images to `gpt-image-1`, transfering the material of one to the other.
- One image is uploaded as a png and the other as a jpeg.
- The output quality is chosen to be `.low` for speed of generation.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image1 = UIImage(named: "my-first-image") else {
        print("Could not find an image named 'my-first-image' in your app assets")
        return
    }

    guard let image2 = UIImage(named: "my-second-image") else {
        print("Could not find an image named 'my-second-image' in your app assets")
        return
    }

    guard let jpegData = AIProxy.encodeImageAsJpeg(image: image1, compressionQuality: 0.4) else {
        print("Could not convert image to jpeg")
        return
    }

    guard let pngData = image2.pngData() else {
        print("Could not convert image to png")
        return
    }

    do {
        let response = try await openAIService.createImageEditRequest(
            body: .init(
                images: [
                    .jpeg(jpegData),
                    .png(pngData)
                ],
                prompt: "Transfer the material of the second image to the first",
                model: .gptImage1,
                quality: .low
            ),
            secondsToWait: 300
        )

        guard let base64Data = response.data.first?.b64JSON,
              let imageData = Data(base64Encoded: base64Data),
              let image = UIImage(data: imageData) else {
            print("Could not create a UIImage out of the base64 returned by OpenAI")
            return
        }

        // Do something with 'image'
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create OpenAI edit image generation: \(error)")
    }
```

### How to make a web search chat completion call with OpenAI

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAIChatCompletionRequestBody(
        model: "gpt-4o-mini-search-preview",
        messages: [.user(
            content: .text("what is Apple's stock price today?")
        )],
        webSearchOptions: .init(
            searchContextSize: .low,
            userLocation: nil
        )
    )
    do {
        let response = try await openAIService.chatCompletionRequest(
            body: requestBody,
            secondsToWait: 60
        )
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not make a web search completion call with OpenAI: \(error)")
    }
```


### How to ensure OpenAI returns JSON as the chat message content

If you need to enforce a strict JSON contract, please use Structured Outputs (the next example)
instead of this approach. This approach is referred to as 'JSON mode' in the OpenAI docs, and
is the predecessor to Structured Outputs.

JSON mode is enabled with `responseFormat: .jsonObject`, while Structured Outputs is enabled
with `responseFormat: .jsonSchema`.

If you use JSON mode, set `responseFormat` *and* specify in the prompt that OpenAI should
return JSON only:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let requestBody = OpenAIChatCompletionRequestBody(
            model: "gpt-4o",
            messages: [
                .system(content: .text("Return valid JSON only")),
                .user(content: .text("Return alice and bob in a list of names"))
            ],
            responseFormat: .jsonObject
        )
        let response = try await openAIService.chatCompletionRequest(body: requestBody)
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create OpenAI chat completion in JSON mode: \(error)")
    }
```

### How to use OpenAI structured outputs (JSON schemas) in a chat response

This example prompts chatGPT to construct a color palette and conform to a strict JSON schema
in its response:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let schema: [String: AIProxyJSONValue] = [
            "type": "object",
            "properties": [
                "colors": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": [
                                "type": "string",
                                "description": "A descriptive name to give the color"
                            ],
                            "hex_code": [
                                "type": "string",
                                "description": "The hex code of the color"
                            ]
                        ],
                        "required": ["name", "hex_code"],
                        "additionalProperties": false
                    ]
                ]
            ],
            "required": ["colors"],
            "additionalProperties": false
        ]
        let requestBody = OpenAIChatCompletionRequestBody(
            model: "gpt-5.2",
            messages: [
                .system(content: .text("Return valid JSON only, and follow the specified JSON structure")),
                .user(content: .text("Return a peaches and cream color palette"))
            ],
            responseFormat: .jsonSchema(
                name: "palette_creator",
                description: "A list of colors that make up a color pallete",
                schema: schema,
                strict: true
            )
        )
        let response = try await openAIService.chatCompletionRequest(body: requestBody)
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create OpenAI chat completion with structured outputs: \(error)")
    }
```


### How to use OpenAI structured outputs with a function call

This implements the example in OpenAI's new [function calling guide](https://platform.openai.com/docs/guides/function-calling).

For more examples, see the [original structured outputs announcement](https://openai.com/index/introducing-structured-outputs-in-the-api).

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )
        func getWeather(location: String?) -> String {
        // Fill this with your native function logic.
        // Using a stub for this example.
        return "Sunny and 65 degrees"
    }

    // We'll start the conversation by asking about the weather.
    // There is no prior history, so we only send up a single user message.
    //
    // You can optionally include a .system message to give the model
    // instructions on how it should behave.
    let userMessage: OpenAIChatCompletionRequestBody.Message = .user(
        content: .text("What is the weather in SF?")
    )

    var completion1: OpenAIChatCompletionResponseBody? = nil
    do {
        completion1 = try await openAIService.chatCompletionRequest(body: .init(
            model: "gpt-5.2",
            messages: [
                userMessage
            ],
            tools: [
                .function(
                    name: "get_weather",
                    description: "Get current temperature for a given location.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "location": [
                                "type": "string",
                                "description": "City and country e.g. Bogotá, Colombia"
                            ]
                        ],
                        "required": ["location"],
                        "additionalProperties": false
                    ],
                    strict: true
                )
            ]
        ))
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not get first chat completion: \(error)")
    }

    // Get the contents of the model's first response:
    guard let toolCall = completion1?.choices.first?.message.toolCalls?.first else {
        print("Completion1: ChatGPT did not respond with a tool call")
        return
    }

    // Invoke the function call natively.
    guard toolCall.function.name == "get_weather" else {
        print("We only know how to get the weather")
        return
    }
    let weather = getWeather(location: toolCall.function.arguments?["location"] as? String)

    // Pass the results of the function call back to OpenAI.
    // We create a second chat completion, note the `messages` array in
    // the completion request. It passes back up:
    //   1. the original user message
    //   2. the response from the assistant, which told us to call the get_weather function
    //   3. the result of our `getWeather` invocation
    let toolMessage: OpenAIChatCompletionRequestBody.Message = .tool(
        content: .text(weather),
        toolCallID: toolCall.id
    )

    var completion2: OpenAIChatCompletionResponseBody? = nil
    do {
        completion2 = try await openAIService.chatCompletionRequest(
            body: .init(
                model: "gpt-5.2",
                messages: [
                    userMessage,
                    .assistant(
                        toolCalls: [
                            .init(
                                id: toolCall.id,
                                function: .init(
                                    name: toolCall.function.name,
                                    arguments: toolCall.function.argumentsRaw
                                )
                            )
                        ]
                    ),
                    toolMessage
                ]
            )
        )
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not get second chat completion: \(error)")
    }

    // Get the contents of the model's second response:
    guard let assistantContent2 = completion2?.choices.first?.message.content else {
        print("Completion2: ChatGPT did not respond with any assistant content")
        return
    }
    print(assistantContent2)
    // Prints: "The weather in San Francisco is sunny with a temperature of 65 degrees Fahrenheit."
```


### How to stream structured outputs tool calls with OpenAI

This example it taken from OpenAI's [function calling guide](https://platform.openai.com/docs/guides/function-calling).

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )
    let requestBody = OpenAIChatCompletionRequestBody(
        model: "gpt-5.2",
        messages: [
            .user(content: .text("What is the weather like in Paris today?")),
        ],
        tools: [
            .function(
                name: "get_weather",
                description: "Get current temperature for a given location.",
                parameters: [
                    "type": "object",
                    "properties": [
                        "location": [
                            "type": "string",
                            "description": "City and country e.g. Bogotá, Colombia"
                        ],
                    ],
                    "required": ["location"],
                    "additionalProperties": false
                ],
                strict: true
            ),
        ]
    )

    do {
        let stream = try await openAIService.streamingChatCompletionRequest(body: requestBody)
        for try await chunk in stream {
            guard let delta = chunk.choices.first?.delta else {
                continue
            }

            // If the model decided to call a function, this branch will be entered:
            if let toolCall = delta.toolCalls?.first {
                if let functionName = toolCall.function?.name {
                    print("ChatGPT wants to call function \(functionName) with arguments...")
                }
                print(toolCall.function?.arguments ?? "")
            }

            // If the model decided to chat, this branch will be entered:
            if let content = delta.content {
                print(content)
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not make a streaming tool call to OpenAI: \(error)")
    }
```

### How to transcribe audio with OpenAI
1. Record an audio file in quicktime and save it as "helloworld.m4a"
2. Add the audio file to your Xcode project. Make sure it's included in your target: select your audio file in the project tree, type `cmd-opt-0` to open the inspect panel, and view `Target Membership`
3. Run this snippet:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let url = Bundle.main.url(forResource: "helloworld", withExtension: "m4a"),
          let fileContents = try? Data(contentsOf: url)
    else {
        print("Could not read file contents of helloworld.m4a")
        return
    }

    do {
        let requestBody = OpenAICreateTranscriptionRequestBody(
            file: fileContents,
            model: "gpt-4o-mini-transcribe",
            responseFormat: "text"
        )
        let response = try await openAIService.createTranscriptionRequest(
            body: requestBody,
            secondsToWait: 120
        )
        print(response.text)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not transcribe audio with OpenAI: \(error)")
    }
```


### How to get Whisper word-level timestamps in an audio transcription with OpenAI

1. Record an audio file in quicktime and save it as "helloworld.m4a"
2. Add the audio file to your Xcode project. Make sure it's included in your target: select your audio file in the project tree, type `cmd-opt-0` to open the inspect panel, and view `Target Membership`
3. Run this snippet:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let url = Bundle.main.url(forResource: "helloworld", withExtension: "m4a"),
          let fileContents = try? Data(contentsOf: url)
    else {
        print("Could not read file contents of helloworld.m4a")
        return
    }

    do {
        let requestBody = OpenAICreateTranscriptionRequestBody(
            file: fileContents,
            model: "whisper-1",
            responseFormat: "verbose_json",
            timestampGranularities: [.word, .segment]
        )
        let response = try await openAIService.createTranscriptionRequest(body: requestBody)
        if let words = response.words {
            for word in words {
                print("\(word.word) from \(word.start) to \(word.end)")
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not get word-level timestamps from OpenAI: \(error)")
    }
```

### How to use OpenAI text-to-speech

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let requestBody = OpenAITextToSpeechRequestBody(
            input: "Hello world",
            voice: .nova
        )

        let mpegData = try await openAIService.createTextToSpeechRequest(body: requestBody)

        // Do not use a local `let` or `var` for AVAudioPlayer.
        // You need the lifecycle of the player to live beyond the scope of this function.
        // Instead, use file scope or set the player as a member of a reference type with long life.
        // For example, at the top of this file you may define:
        //
        //   fileprivate var audioPlayer: AVAudioPlayer? = nil
        //
        // And then use the code below to play the TTS result:
        audioPlayer = try AVAudioPlayer(data: mpegData)
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create OpenAI TTS audio: \(error)")
    }
```


### How to classify text as potentially harmful with OpenAI moderations

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAIModerationRequestBody(
        input: [
            .text("is this bad"),
        ],
        model: "omni-moderation-latest"
    )
    do {
        let response = try await openAIService.moderationRequest(body: requestBody)
        print("Is this content flagged: \(response.results.first?.flagged ?? false)")
        //
        // For a more detailed assessment of the input content, inspect:
        //
        //     response.results.first?.categories
        //
        // and
        //
        //     response.results.first?.categoryScores
        //
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not perform moderation request to OpenAI")
    }
```

### How to classify images as potentially harmful with OpenAI moderations

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = NSImage(named: "myImage") else {
        print("Could not find an image named 'myImage' in your app assets")
        return
    }

    guard let imageURL = AIProxy.encodeImageAsURL(image: image, compressionQuality: 0.4) else {
        print("Could not encode image as data URL")
        return
    }

    let requestBody = OpenAIModerationRequestBody(
        input: [
            .image(imageURL)
        ],
        model: "omni-moderation-latest"
    )

    do {
        let response = try await openAIService.moderationRequest(body: requestBody)
        print("Is this content flagged: \(response.results.first?.flagged ?? false)")
        //
        // For a more detailed assessment of the input content, inspect:
        //
        //     response.results.first?.categories
        //
        // and
        //
        //     response.results.first?.categoryScores
        //
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not perform image moderation request to OpenAI")
    }
```

### How to get embeddings using OpenAI

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAIEmbeddingRequestBody(
        input: .text("hello world"),
        model: "text-embedding-3-small"
    )

    // Or, for multiple embeddings from strings:

    /*
    let requestBody = OpenAIEmbeddingRequestBody(
        input: .textArray([
            "hello world",
            "hola mundo"
        ]),
        model: "text-embedding-3-small"
    )
    */

    // Or, for multiple embeddings from tokens:

    /*
    let requestBody = OpenAIEmbeddingRequestBody(
        input: .intArray([0,1,2]),
        model: "text-embedding-3-small"
    )
    */

    do {
        let response = try await openAIService.embeddingRequest(body: requestBody)
        print(
            """
            The response contains \(response.embeddings.count) embeddings.

            The first vector starts with \(response.embeddings.first?.vector.prefix(10) ?? [])
            """
        )
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not perform embedding request to OpenAI: \(error)")
    }
```


### How to use realtime audio with OpenAI

Use this example to have a conversation with OpenAI's realtime models.

If you're building for iOS, see the [OpenAI realtime starter](https://github.com/lzell/OpenAIRealtimeSample) project for a jumping off point.

We recommend getting a basic chat completion with OpenAI working before attempting realtime.
Realtime is a more involved integration (as you can see from the code snippet below), and
getting a basic integration working first narrows down the source of any problem.

Take these steps to build and run an OpenAI realtime example: 

1. Generate a new SwiftUI Xcode project
2. Add the `NSMicrophoneUsageDescription` key to your info.plist file
3. If macOS, tap your project > your target > Signing & Capabilities and add the following:
    - App Sandbox > Outgoing Connections (client)
    - App Sandbox > Audio Input
    - Hardened Runtime > AudioInput
4. Replace the contents of `ContentView.swift` with the snippet below
5. Replace the placeholders in the snippet
    - If connecting directly to OpenAI, replace `your-openai-key`
    - If protecting your connection through AIProxy, replace `aiproxy-partial-key` and `aiproxy-service-url`
6. Set the `logLevel` argument of the `openAIService.realtimeSession` call to your desired level. If you leave
   it set at `.debug`, then you'll see logs for all audio samples that we send and receive from OpenAI. 

```swift
import SwiftUI
import AIProxy

struct ContentView: View {
    let realtimeManager = RealtimeManager()
    @State private var isRealtimeActive: Bool = false {
        willSet {
            if newValue {
                startRealtime()
            } else {
                stopRealtime()
            }
        }
    }

    private func startRealtime() {
        Task {
            do {
                try await realtimeManager.startConversation()
            } catch {
                print("Could not start OpenAI realtime: \(error)")
            }
        }
    }

    private func stopRealtime() {
        Task {
            await realtimeManager.stopConversation()
        }
    }

    var body: some View {
        VStack {
            Button(isRealtimeActive ? "Stop OpenAI Realtime" : "Start OpenAI Realtime") {
                self.isRealtimeActive.toggle()
            }
        }
    }
}


@AIProxyActor
final class RealtimeManager {
    private var realtimeSession: OpenAIRealtimeSession?
    private var audioController: AudioController?

    nonisolated init() {}

    func startConversation() async throws {
        /* Uncomment for BYOK use cases */
        // let openAIService = AIProxy.openAIDirectService(
        //     unprotectedAPIKey: "your-openai-key"
        // )

        /* Uncomment to protect your connection through AIProxy */
        // let openAIService = AIProxy.openAIService(
        //     partialKey: "partial-key-from-your-developer-dashboard",
        //     serviceURL: "service-url-from-your-developer-dashboard"
        // )

        // Set to false if you want your user to speak first
        let aiSpeaksFirst = true

        let audioController = try await AudioController(
            modes: [.playback, .record],
            useManualEchoCancellation: true
        )
        let micStream = try audioController.micStream()

        // Start the realtime session:
        let configuration = OpenAIRealtimeSessionConfiguration(
            inputAudioFormat: .pcm16,
            inputAudioTranscription: .init(model: "whisper-1"),
            instructions: "You are a tour guide of Yosemite national park",
            maxOutputTokens: .int(4096),
            outputModalities: [.audio],
            outputAudioFormat: .pcm16,
            turnDetection: .semanticVAD(.init(eagerness: .medium)),
            voice: "shimmer"
        )

        let realtimeSession = try await openAIService.realtimeSession(
            model: "gpt-realtime-2",
            configuration: configuration,
            logLevel: .debug
        )

        // Send audio from the microphone to OpenAI once OpenAI is ready for it:
        var isOpenAIReadyForAudio = false
        Task {
            for await buffer in micStream {
                if isOpenAIReadyForAudio, let base64Audio = AIProxy.base64EncodeAudioPCMBuffer(from: buffer) {
                    await realtimeSession.sendMessage(
                        OpenAIRealtimeInputAudioBufferAppend(audio: base64Audio)
                    )
                }
            }
        }

        // Listen for messages from OpenAI:
        Task {
            for await message in realtimeSession.receiver {
                switch message {
                case .error(_):
                    realtimeSession.disconnect()
                case .sessionUpdated:
                    if aiSpeaksFirst {
                        await realtimeSession.sendMessage(OpenAIRealtimeResponseCreate())
                    } else {
                        isOpenAIReadyForAudio = true
                    }
                case .responseAudioDelta(let delta):
                    audioController.playPCM16Audio(base64String: delta.base64String)
                case .inputAudioBufferSpeechStarted:
                    audioController.interruptPlayback()
                case .responseCreated:
                    isOpenAIReadyForAudio = true
                default:
                    break
                }
            }
        }

        self.realtimeSession = realtimeSession
        self.audioController = audioController
    }

    func stopConversation() {
        self.audioController?.stop()
        self.realtimeSession?.disconnect()
        self.audioController = nil
        self.realtimeSession = nil
    }
}
```

#### Current Realtime API notes

- For a field-by-field mapping of the Realtime wire shape to AIProxySwift types, see
  [Realtime schema matrix](Documentation/OpenAI/RealtimeSchemaMatrix.md).
- For `response.create`, the current Realtime API uses `output_modalities` (not `modalities`).
- `output_modalities` is as follows:
  - `["audio"]` returns audio with transcript.
  - `["text"]` returns text only.
- For voice mode with built-in web search, use the `.webSearch` tool and specify `.auto` for `toolChoice` to let the model decide when to use it.

```swift
let configuration = OpenAIRealtimeSessionConfiguration(
    outputModalities: [.audio],
    voice: .builtin("alloy"),
    tools: [.webSearch(.init(searchContextSize: .medium))],
    toolChoice: .auto
)

let session = try await openAIService.realtimeSession(
    model: "gpt-realtime",
    configuration: configuration,
    logLevel: .info
)
```

#### Realtime Reasoning models

OpenAI's Realtime Reasoning models, such as `gpt-realtime-2`, use the same Realtime WebSocket
transport and shared session fields as Performance models like `gpt-realtime-1.5`, plus
Reasoning-only configuration for effort and parallel tool calls.

```swift
let configuration = OpenAIRealtimeReasoningSessionConfiguration(
    session: OpenAIRealtimeSessionConfiguration(
        outputModalities: [.audio],
        voice: .builtin("alloy"),
        tools: [.webSearch(.init(searchContextSize: .medium))],
        toolChoice: .auto
    ),
    reasoning: .init(effort: .low),
    parallelToolCalls: true
)

let session = try await openAIService.realtimeSession(
    model: "gpt-realtime-2",
    configuration: configuration,
    logLevel: .info
)
```

You can also override Reasoning settings for a single response:

```swift
await session.sendMessage(
    OpenAIRealtimeReasoningResponseCreate(
        response: .init(
            base: .init(
                instructions: "Use the lowest sufficient reasoning effort.",
                outputModalities: [.audio]
            ),
            reasoning: .init(effort: .minimal),
            parallelToolCalls: false
        )
    )
)
```

Realtime Reasoning responses can include phased output. Use `phase` to separate short commentary
from the final answer when the model emits both in a turn:

```swift
for await message in session.receiver {
    if case .responseDone(let event) = message {
        let commentary = event.output?.filter { $0.phase == .commentary }
        let finalAnswer = event.output?.filter { $0.phase == .finalAnswer }
    }
}
```

### How to make a basic request using OpenAI's Responses API
Note: there is also a streaming version of this snippet below.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAICreateResponseRequestBody(
        input: .text("hello world"),
        model: "gpt-5.1",
        reasoning: .init(effort: .noReasoning),
        text: .init(verbosity: .high),                           // Optional: Use low verbosity for concise responses
        previousResponseId: nil                                  // Pass this on future requests to save chat history
    )

    do {
        let response = try await openAIService.createResponse(requestBody: requestBody)
        print(response.outputText)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not get a text response from OpenAI: \(error)")
    }
```

### How to make a tool call request with OpenAI's Responses API

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let schema: [String: AIProxyJSONValue] = [
        "type": "object",
        "properties": [
            "location": [
                "type": "string",
                "description": "City and country e.g. Bogotá, Colombia"
            ]
        ],
        "required": ["location"],
        "additionalProperties": false
    ]

    let requestBody = OpenAICreateResponseRequestBody(
        input: .text("What is the weather like in Paris today?"),
        model: "gpt-4o",
        tools: [
            .function(
                .init(
                    name: "get_weather",
                    parameters: schema
                )
            )
        ]
    )

    do {
        let response = try await openAIService.createResponse(
            requestBody: requestBody,
            secondsToWait: 60
        )
        if case .functionCall(let functionCall) = response.output.first {
            print("""
                  The model wants to call function: \(functionCall.name)
                  with arguments: \(functionCall.arguments)")
                  """)
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create a tool call response from OpenAI: \(error)")
    }
```

### How to make a Structured Outputs request with OpenAI's Responses API

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let schema: [String: AIProxyJSONValue] = [
        "type": "object",
        "properties": [
            "colors": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "name": [
                            "type": "string",
                            "description": "A descriptive name to give the color"
                        ],
                        "hex_code": [
                            "type": "string",
                            "description": "The hex code of the color"
                        ]
                    ],
                    "required": ["name", "hex_code"],
                    "additionalProperties": false
                ]
            ]
        ],
        "required": ["colors"],
        "additionalProperties": false
    ]
    let requestBody = OpenAICreateResponseRequestBody(
        input: .items([
            .message(role: .system, content: .text("You are a color palette generator")),
            .message(role: .user, content: .text("Return a peaches and cream color palette"))
        ]),
        model: "gpt-4o",
        text: .init(
            format: .jsonSchema(
                name: "palette",
                schema: schema,
                description: "A list of colors that make up a color pallete",
                strict: true
            )
        )
    )

    do {
        let response = try await openAIService.createResponse(
            requestBody: requestBody,
            secondsToWait: 120
        )
        print(response.outputText)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not get a structured output response from OpenAI: \(error)")
    }
```

### How to make a JSON mode request with OpenAI's Responses API

Please also see the Structured Outputs snippet above, which is a more modern way of getting a JSON response

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAICreateResponseRequestBody(
        input: .items([
            .message(role: .system, content: .text("Return valid JSON only")),
            .message(role: .user, content: .text("Return alice and bob in a list of names"))
        ]),
        model: "gpt-4o",
        text: .init(format: .jsonObject)
    )

    do {
        let response = try await openAIService.createResponse(
            requestBody: requestBody,
            secondsToWait: 120
        )
        print(response.outputText)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not get a JSON mode response from OpenAI: \(error)")
    }
```

### How to use an image as input (multi-modal) using OpenAI's Responses API

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = UIImage(named: "myImage") else {
        print("Could not find an image named 'myImage' in your app assets")
        return
    }

    guard let imageURL = AIProxy.encodeImageAsURL(image: image, compressionQuality: 0.5) else {
        print("Could not encode image as data URL")
        return
    }

    let requestBody = OpenAICreateResponseRequestBody(
        input: .items(
            [
                .message(
                    role: .system,
                    content: .text("You are a visual assistant")
                ),
                .message(
                    role: .user,
                    content: .list([
                        .text("What do you see?"),
                        .imageURL(imageURL)
                    ])
                )
            ]
        ),
        model: "gpt-4o"
    )

    do {
        let response = try await openAIService.createResponse(
            requestBody: requestBody,
            secondsToWait: 60
        )
        print(response.outputText)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create a multi-modal OpenAI Response: \(error)")
    }
```

### How to make a web search call using OpenAI's Responses API
Note: there is also a streaming version of this snippet below.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAICreateResponseRequestBody(
        input: .text("What is Apple's stock price today?"),
        model: "gpt-4o",
        tools: [
            .webSearch(.init(searchContextSize: .low))
        ]
    )

    do {
        let response = try await openAIService.createResponse(requestBody: requestBody)
        print(response.outputText)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not get web search result from OpenAI: \(error)")
    }
```

### How to use a stored file in an OpenAI prompt using the Responses API

Note: This example is for including a file in a prompt. For searching through a file, see the vector store examples below.

Replace the `fileID` with the ID returned from the snippet `How to upload a file to OpenAI's file storage`

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )
    let requestBody = OpenAICreateResponseRequestBody(
        input: .items(
            [
                .message(role: .user, content: .list(
                    [
                        .file(fileID: "your-file-ID"),
                        .text("What is the purpose of this doc?")
                    ])
                )
            ]
        ),
        model: "gpt-4o"
    )

    do {
        let response = try await openAIService.createResponse(requestBody: requestBody)
        print(response.outputText)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not prompt with file contents: \(error)")
    }
```

### How to use image inputs in the OpenAI Responses API

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    // Example of using a local image
    guard let garmentImage = NSImage(named: "tshirt"),
          let garmentImageURL = AIProxy.encodeImageAsURL(image: garmentImage,
                                                         compressionQuality: 0.5) else {
        print("Could not find an image named 'tshirt' in your app assets")
        return
    }

    // Example of using a remote image
    let remoteImageURL = URL(string: "https://www.aiproxy.com/assets/img/requests.png")!

    let requestBody = OpenAICreateResponseRequestBody(
        input: .items(
            [
                .message(
                    role: .user,
                    content: .list([
                        .text("What are in these images?"),
                        .imageURL(garmentImageURL),
                        .imageURL(remoteImageURL),
                    ])
                ),
            ]
        ),
        model: "gpt-4o-mini"
    )

    do {
        let response = try await openAIService.createResponse(requestBody: requestBody)
        print(response.outputText)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not prompt with image inputs: \(error)")
    }
```

### How to create a vector store with default chunking on OpenAI

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )


    let requestBody = OpenAICreateVectorStoreRequestBody(
        chunkingStrategy: .auto,
        name: "my-vector-store"
    )
    do {
        let vectorStore = try await openAIService.createVectorStore(
            requestBody: requestBody,
            secondsToWait: 60
        )
        print("Created vector store with id: \(vectorStore.id)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create an OpenAI vector store: \(error)")
    }
```

### How to create a vector store with specific chunking on OpenAI

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAICreateVectorStoreRequestBody(
        chunkingStrategy: .static(chunkOverlapTokens: 300, maxChunkSizeTokens: 700),
        name: "my-vector-store"
    )

    do {
        let vectorStore = try await openAIService.createVectorStore(
            requestBody: requestBody,
            secondsToWait: 60
        )
        print("Created vector store with id: \(vectorStore.id)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create an OpenAI vector store: \(error)")
    }
```

### How to upload a file to OpenAI's file storage

Add the file `The-Swift-Programming-Language.pdf` to your Xcode project tree.
This will upload the pdf to OpenAI for use in a future vector store request:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let localURL = Bundle.main.url(forResource: "The-Swift-Programming-Language", withExtension: "pdf"),
          let pdfData = try? Data(contentsOf: localURL) else {
        print("Drop The-Swift-Programming-Language.pdf file the project tree first.")
        return
    }

    do {
        let openAIFile = try await openAIService.uploadFile(
            contents: pdfData,
            name: "The-Swift-Programming-Language.pdf",
            purpose: .userData,
            secondsToWait: 300
        )
        print("""
              File uploaded to OpenAI's media storage.
              It will be available until \(openAIFile.expiresAt.flatMap {String($0)} ?? "forever")
              Use it in subsequent requests with ID: \(openAIFile.id)
              """)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not upload file to OpenAI: \(error)")
    }
```

### How to add an uploaded file to an OpenAI vector store

You'll need two IDs for this snippet:
1. The file ID returned in the `How to upload a file to OpenAI's file storage` snippet
2. The vector store ID returned in the `How to create a vector store with default chunking on OpenAI` snippet

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let fileID = /* ID from the file upload example */
    let vectorStoreID = /* ID from the vector store example */

    let requestBody = OpenAICreateVectorStoreFileRequestBody(
        fileID: fileID
    )
    do {
        let vectorStoreFile = try await openAIService.createVectorStoreFile(
            vectorStoreID: vectorStoreID,
            requestBody: requestBody,
            secondsToWait: 120
        )
        print("Created vector store file with id: \(vectorStoreFile.id ?? "unknown")")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create an OpenAI vector store file: \(error)")
    }
```

### How to make a streaming request using OpenAI's Responses API

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )
    let requestBody = OpenAICreateResponseRequestBody(
        input: .text("hello world"),
        model: "gpt-4o"
    )

    do {
        let stream = try await openAIService.createStreamingResponse(requestBody: requestBody)
        for try await event in stream {
            switch event {
            case .outputTextDelta(let outputTextDelta):
                print(outputTextDelta.delta)
            default:
                break
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not get a streaming response from OpenAI: \(error)")
    }
```

### How to make a streaming function call through OpenAI's Responses API

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let schema: [String: AIProxyJSONValue] = [
        "type": "object",
        "properties": [
            "location": [
                "type": "string",
                "description": "City and country e.g. Bogotá, Colombia"
            ]
        ],
        "required": ["location"],
        "additionalProperties": false
    ]

    let requestBody = OpenAICreateResponseRequestBody(
        input: .text("What is the weather like in Paris today?"),
        model: "gpt-4o",
        tools: [
            .function(
                .init(
                    name: "get_weather",
                    parameters: schema
                )
            )
        ]
    )

    do {
        let stream = try await openAIService.createStreamingResponse(requestBody: requestBody)
        for try await event in stream {
            switch event {
            case .functionCallArgumentsDelta(let functionCallArgumentsDelta):
                print(functionCallArgumentsDelta.delta)
            default:
                break
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not get a streaming response from OpenAI: \(error)")
    }
```

### How to make a streaming web search call through OpenAI's Responses API

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAICreateResponseRequestBody(
        input: .text("What is Apple's stock price today?"),
        model: "gpt-4o",
        tools: [
            .webSearch(.init(searchContextSize: .low))
        ]
    )

    do {
        let stream = try await openAIService.createStreamingResponse(requestBody: requestBody)
        for try await event in stream {
            switch event {
            case .outputTextDelta(let outputTextDelta):
                print(outputTextDelta.delta)
            default:
                break
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not get a text response from OpenAI: \(error)")
    }
```

### How to make a streaming file search call through OpenAI's Responses API

To run this snippet, you'll first need to add your files to a vector store.
See the snippet above titled `How to add an uploaded file to an OpenAI vector store`.
Once your files are added and processed, you can run this snippet on your `vectorStoreID`.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let vectorStoreID = /* your vector store ID */
    let requestBody = OpenAICreateResponseRequestBody(
        input: .text("How do I use 'async let'?"),
        model: "gpt-4o",
        tools: [
            .fileSearch(
                .init(
                    vectorStoreIDs: [
                        vectorStoreID
                    ]
                )
            )
        ]
    )
    do {
        let stream = try await openAIService.createStreamingResponse(requestBody: requestBody)
        for try await event in stream {
            switch event {
            case .outputTextDelta(let outputTextDelta):
                print(outputTextDelta.delta)
            case .outputTextAnnotationAdded(let outputTextAnnotationAdded):
                if case .fileCitation(let fileCitation) = outputTextAnnotationAdded.annotation {
                    print("Citing: \(fileCitation.filename) at index: \(fileCitation.index)")
                }
            default:
                break
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not get a text response from OpenAI: \(error)")
    }
```

### How to use prompt templates with the OpenAI Responses API

- Follow OpenAI's guide for [creating a prompt](https://platform.openai.com/docs/guides/prompting#create-a-prompt).
- Use the returned prompt ID in the snippet below
- Fill in the prompt variables as part of the request body (for example, I used the variable 'topic' below)


```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let templateID = "<your-prompt-ID-here>"
    let requestBody = OpenAICreateResponseRequestBody(
        model: "gpt-5",
        prompt: .init(
            id: templateID,
            variables: [
                "topic": .text("sandwiches")
            ],
            version: "1"
        )
    )
    do {
        // Uncomment for the buffered case:
        let response = try await openAIService.createResponse(
            requestBody: requestBody,
            secondsToWait: 60
        )
        print(response.outputText)

        // Uncomment for the streaming case:
        // let stream = try await openAIService.createStreamingResponse(
        //     requestBody: requestBody,
        //     secondsToWait: 60
        // )
        // for try await event in stream {
        //     switch event {
        //     case .outputTextDelta(let outputTextDelta):
        //         print(outputTextDelta.delta)
        //     default:
        //         break
        //     }
        // }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not get a text response from OpenAI: \(error)")
    }
}
```

### How to use OpenAI through an Azure deployment

You can use all of the OpenAI snippets aboves with one change. Initialize the OpenAI service with:

```swift
    import AIProxy

    let openAIService = AIProxy.openAIService(
        partialKey: "partial-key-from-your-developer-dashboard",
        serviceURL: "service-url-from-your-developer-dashboard",
        requestFormat: .azureDeployment(apiVersion: "2024-06-01")
    )
```

***

## OpenAI Conversations API

### How to create an OpenAI conversation

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAICreateConversationRequestBody(
        items: [
            .item(
                .inputMessage(OpenAIInputMessage(content: "Hello world", role: .user))
            )
        ],
        metadata: ["topic": "demo"]
    )

    do {
         let response = try await openAIService.createConversation(
             requestBody: requestBody,
             secondsToWait: 120
         )
        print("Created conversation with ID: \(response.id)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create OpenAI Conversation: \(error)")
    }
```

### How to get an OpenAI conversation

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let response = try await openAIService.getConversation(
            conversationID: "<conversation-id>",
            secondsToWait: 120
        )
        print("Retreived conversation with ID \(response.id) and metadata: \(response.metadata)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not get OpenAI Conversation: \(error)")
    }
```

### How to list OpenAI conversation items

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let response = try await openAIService.listItems(
            conversationID: "<conversation-id>",
            include: [.messageOutputTextLogprobs],
            secondsToWait: 120
        )
        print("Retreived conversation with ID \(response.data)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not list OpenAI conversation items: \(error)")
    }
```

### How to add items to an OpenAI conversation

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let createConversationBody = OpenAICreateConversationRequestBody(
        metadata: ["purpose": "item_creation_test"]
    )

    do {
        let conversation = try await openAIService.createConversation(
            requestBody: createConversationBody,
            secondsToWait: 120
        )
        print("Created conversation: \(conversation.id)")

        let createItemsBody = OpenAICreateConversationItemsRequestBody(
            items: [
                .item(
                    .inputMessage(OpenAIInputMessage(content: "What is the capital of France?", role: .user))
                )
            ]
        )

        let response = try await openAIService.createItems(
            conversationID: conversation.id,
            requestBody: createItemsBody,
            secondsToWait: 120
        )
        print("Created \(response.data.count) items in conversation")
        print("First item ID: \(response.firstID)")
        print("Last item ID: \(response.lastID)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create conversation items: \(error)")
    }
```

### How to delete an item from an OpenAI conversation

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let result = try await openAIService.deleteItem(
            conversationID: <conversation-id>,
            itemID: <item-id>,
            secondsToWait: 120
        )
        print("Deleted conversation item with id: \(result.id)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not delete conversation item: \(error)")
    }
```

### How to delete an OpenAI conversation

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let response = try await openAIService.deleteConversation(
            conversationID: "<conversation-id>",
            secondsToWait: 120
        )
        print("Conversation with ID \(response.id) has been deleted: \(response.deleted)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not delete OpenAI Conversation: \(error)")
    }
```

### How to list OpenAI conversation items with pagination

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let createConversationBody = OpenAICreateConversationRequestBody(
        items: [
            .item(.inputMessage(OpenAIInputMessage(content: "Page 1 - Item 1", role: .user))),
            .item(.inputMessage(OpenAIInputMessage(content: "Page 1 - Item 2", role: .user))),
            .item(.inputMessage(OpenAIInputMessage(content: "Page 2 - Item 1", role: .user))),
            .item(.inputMessage(OpenAIInputMessage(content: "Page 2 - Item 2", role: .user)))
        ],
        metadata: ["purpose": "pagination_test"]
    )

    do {
        let conversation = try await openAIService.createConversation(
            requestBody: createConversationBody,
            secondsToWait: 120
        )
        print("Created conversation: \(conversation.id)")

        let page1 = try await openAIService.listItems(
            conversationID: conversation.id,
            limit: 2,
            order: .asc,
            secondsToWait: 120
        )
        print("Page 1: \(page1.data.count) items")
        print("Has more: \(page1.hasMore)")

        if page1.hasMore {
            let page2 = try await openAIService.listItems(
                conversationID: conversation.id,
                after: page1.lastID,
                limit: 2,
                order: .asc,
                secondsToWait: 120
            )
            print("Page 2: \(page2.data.count) items")
            print("Has more: \(page2.hasMore)")
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not paginate conversation items: \(error)")
    }
```

***

## Gemini

### How to generate text content with Gemini

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = GeminiGenerateContentRequestBody(
        contents: [
            .init(
                parts: [.text("How do I use product xyz?")]
            )
        ],
        systemInstruction: .init(parts: [.text("Introduce yourself as a customer support person")])
    )
    do {
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash",
            secondsToWait: 60
        )
        for part in response.candidates?.first?.content?.parts ?? [] {
            switch part {
            case .text(let text):
                print("Gemini sent: \(text)")
            case .functionCall(name: let functionName, args: let arguments):
                print("Gemini wants us to call function \(functionName) with arguments: \(arguments ?? [:])")
            }
        }
        if let usage = response.usageMetadata {
            print(
                """
                Used:
                 \(usage.promptTokenCount ?? 0) prompt tokens
                 \(usage.cachedContentTokenCount ?? 0) cached tokens
                 \(usage.candidatesTokenCount ?? 0) candidate tokens
                 \(usage.totalTokenCount ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create Gemini generate content request: \(error)")
    }
```

### How to generate streaming text content with Gemini

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = GeminiGenerateContentRequestBody(
        contents: [
            .init(
                parts: [.text("How do I use product xyz?")]
            )
        ],
        safetySettings: [
            .init(category: .dangerousContent, threshold: .none),
            .init(category: .civicIntegrity, threshold: .none),
            .init(category: .harassment, threshold: .none),
            .init(category: .hateSpeech, threshold: .none),
            .init(category: .sexuallyExplicit, threshold: .none)
        ],
        systemInstruction: .init(parts: [.text("Introduce yourself as a customer support person")])
    )
    do {
        let stream = try await geminiService.generateStreamingContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash",
            secondsToWait: 60
        )
        for try await chunk in stream {
            for part in chunk.candidates?.first?.content?.parts ?? [] {
                if case .text(let text) = part {
                    print(text)
                }
            }
        }
        print("Gemini finished streaming")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not generate Gemini streaming content: \(error)")
    }
```

### How to make a tool call with Gemini

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let functionParameters: [String: AIProxyJSONValue] = [
        "type": "OBJECT",
        "properties": [
            "brightness": [
                "description": "Light level from 0 to 100. Zero is off and 100 is full brightness.",
                "type": "NUMBER"
            ],
            "colorTemperature": [
                "description": "Color temperature of the light fixture which can be `daylight`, `cool` or `warm`.",
                "type": "STRING"
            ]
        ],
        "required": [
            "brightness",
            "colorTemperature"
        ]
    ]

    let requestBody = GeminiGenerateContentRequestBody(
        contents: [
            .init(
                parts: [.text("Dim the lights so the room feels cozy and warm.")],
                role: "user"
            )
        ],
        /* Uncomment this to enforce that a function is called regardless of prompt contents. */
        // toolConfig: .init(
        //     functionCallingConfig: .init(
        //         allowedFunctionNames: ["controlLight"],
        //         mode: .anyFunction
        //     )
        // ),
        tools: [
            .functionDeclarations(
                [
                    .init(
                        name: "controlLight",
                        description: "Set the brightness and color temperature of a room light.",
                        parameters: functionParameters
                    )
                ]
            )
        ]
    )

    do {
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash",
            secondsToWait: 60
        )
        for part in response.candidates?.first?.content?.parts ?? [] {
            switch part {
            case .text(let text):
                print("Gemini sent: \(text)")
            case .functionCall(name: let functionName, args: let arguments):
                print("Gemini wants us to call function \(functionName) with arguments: \(arguments ?? [:])")
            }
        }
        if let usage = response.usageMetadata {
            print(
                """
                Used:
                 \(usage.promptTokenCount ?? 0) prompt tokens
                 \(usage.cachedContentTokenCount ?? 0) cached tokens
                 \(usage.candidatesTokenCount ?? 0) candidate tokens
                 \(usage.totalTokenCount ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create Gemini tool (function) call: \(error)")
    }
```

### How to make a google search grounding call with Gemini 2.0

It's important that you connect a GCP billing account to your Gemini API key to use this
feature. Otherwise, Gemini will return 429s for every call. You can connect your billing
account for the API keys you use [here](https://aistudio.google.com/app/apikey).

Consider applying to [google for startups](https://cloud.google.com/startup?hl=en) to gain
credits that you can put towards Gemini.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )
    let requestBody = GeminiGenerateContentRequestBody(
        contents: [
            .init(
                parts: [.text("What is the price of Google stock today")],
                role: "user"
            )
        ],
        generationConfig: .init(
            temperature: 0.7
        ),
        systemInstruction: .init(
            parts: [.text("You are a helpful assistant")]
        ),
        tools: [
            .googleSearch()
        ]
    )

    do {
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash",
            secondsToWait: 60
        )
        for candidate in response.candidates ?? [] {
            for part in candidate.content?.parts ?? [] {
                if case .text(let text) = part {
                    print("Gemini sent: \(text)\n")
                    print("Gemini used \(candidate.groundingMetadata?.groundingChunks?.count ?? 0) grounding chunks")
                    print("Gemini used \(candidate.groundingMetadata?.groundingSupports?.count ?? 0) grounding supports")
                }
            }

            for groundingChunk in candidate.groundingMetadata?.groundingChunks ?? [] {
                if let url = groundingChunk.web?.url {
                    print("Grounding URL: \(url)")
                }
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create Gemini google search grounding request: \(error)")
    }
```

### How to transcribe audio with Gemini

Add a file called `helloworld.m4a` to your Xcode assets before running this sample snippet:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let url = Bundle.main.url(forResource: "helloworld", withExtension: "m4a") else {
        print("Could not find an audio file named helloworld.m4a in your app bundle")
        return
    }

    do {
        let requestBody = GeminiGenerateContentRequestBody(
            contents: [
                .init(
                    parts: [
                        .text("""
                              Can you transcribe this interview, in the format of timecode, speaker, caption?
                              Use speaker A, speaker B, etc. to identify speakers.
                              """),
                        .inline(data: try Data(contentsOf: url), mimeType: "audio/mp4")
                    ]
                )
            ]
        )
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash",
            secondsToWait: 60
        )
        for part in response.candidates?.first?.content?.parts ?? [] {
            switch part {
            case .text(let text):
                print("Gemini transcript: \(text)")
            case .functionCall(name: let functionName, args: let arguments):
                print("Gemini wants us to call function \(functionName) with arguments: \(arguments ?? [:])")
            }
        }
        if let usage = response.usageMetadata {
            print(
                """
                Used:
                 \(usage.promptTokenCount ?? 0) prompt tokens
                 \(usage.cachedContentTokenCount ?? 0) cached tokens
                 \(usage.candidatesTokenCount ?? 0) candidate tokens
                 \(usage.totalTokenCount ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create transcript with Gemini: \(error)")
    }
```

### How to use images in the prompt to Gemini

Add a file called 'my-image.jpg' to Xcode app assets. Then run this snippet:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = NSImage(named: "my-image") else {
        print("Could not find an image named 'my-image' in your app assets")
        return
    }

    guard let jpegData = AIProxy.encodeImageAsJpeg(image: image, compressionQuality: 0.6) else {
        print("Could not encode image as Jpeg")
        return
    }

    do {
        let requestBody = GeminiGenerateContentRequestBody(
            contents: [
                .init(
                    parts: [
                        .text("What do you see?"),
                        .inline(
                            data: jpegData,
                            mimeType: "image/jpeg"
                        )
                    ]
                )
            ],
            safetySettings: [
                .init(category: .dangerousContent, threshold: .none),
                .init(category: .civicIntegrity, threshold: .none),
                .init(category: .harassment, threshold: .none),
                .init(category: .hateSpeech, threshold: .none),
                .init(category: .sexuallyExplicit, threshold: .none)
            ]
        )
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash",
            secondsToWait: 60
        )
        for part in response.candidates?.first?.content?.parts ?? [] {
            switch part {
            case .text(let text):
                print("Gemini sees: \(text)")
            case .functionCall(name: let functionName, args: let arguments):
                print("Gemini wants us to call function \(functionName) with arguments: \(arguments ?? [:])")
            }
        }
        if let usage = response.usageMetadata {
            print(
                """
                Used:
                 \(usage.promptTokenCount ?? 0) prompt tokens
                 \(usage.cachedContentTokenCount ?? 0) cached tokens
                 \(usage.candidatesTokenCount ?? 0) candidate tokens
                 \(usage.totalTokenCount ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create Gemini generate content request: \(error)")
    }
```

### How to upload a video file to Gemini temporary storage

Add a file called `my-movie.mov` to your Xcode assets before running this sample snippet.
If you use a file like `my-movie.mp4`, change the mime type from `video/quicktime` to `video/mp4` in the snippet below.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    // Try to upload the zip file in Xcode assets
    // Get the images to train with:
    guard let movieAsset = NSDataAsset(name: "my-movie") else {
        print("""
              Drop my-movie.mov into Assets first.
              """)
        return
    }

    do {
        let geminiFile = try await geminiService.uploadFile(
            fileData: movieAsset.data,
            mimeType: "video/quicktime"
        )
        print("""
              Video file uploaded to Gemini's media storage.
              It will be available for 48 hours.
              Find it at \(geminiFile.uri.absoluteString)
              """)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not upload file to Gemini: \(error)")
    }
```

### How to convert video contents to text with Gemini

Use the file URL returned from the snippet above.

```swift
    import AIProxy

    let fileURL = URL(string: "url-from-snippet-above")!

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = GeminiGenerateContentRequestBody(
        contents: [
            .init(
                parts: [
                    .text("Dump the text content in markdown from this video"),
                    .file(
                        url: fileURL,
                        mimeType: "video/quicktime"
                    )
                ]
            )
        ],
        safetySettings: [
            .init(category: .dangerousContent, threshold: .none),
            .init(category: .civicIntegrity, threshold: .none),
            .init(category: .harassment, threshold: .none),
            .init(category: .hateSpeech, threshold: .none),
            .init(category: .sexuallyExplicit, threshold: .none)
        ]
    )

    do {
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash",
            secondsToWait: 60
        )
        for part in response.candidates?.first?.content?.parts ?? [] {
            switch part {
            case .text(let text):
                print("Gemini transcript: \(text)")
            case .functionCall(name: let functionName, args: let arguments):
                print("Gemini wants us to call function \(functionName) with arguments: \(arguments ?? [:])")
            }
        }
        if let usage = response.usageMetadata {
            print(
                """
                Used:
                 \(usage.promptTokenCount ?? 0) prompt tokens
                 \(usage.cachedContentTokenCount ?? 0) cached tokens
                 \(usage.candidatesTokenCount ?? 0) candidate tokens
                 \(usage.totalTokenCount ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create Gemini vision request: \(error)")
    }
```

### How to delete a temporary file from Gemini storage

```swift
    import AIProxy

    let fileURL = URL(string: "url-from-snippet-above")!

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        try await geminiService.deleteFile(fileURL: fileURL)
        print("File deleted from \(fileURL.absoluteString)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not delete file from Gemini temporary storage: \(error)")
    }
```

### How to use structured ouputs with Gemini

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let schema: [String: AIProxyJSONValue] = [
        "description": "List of recipes",
        "type": "array",
        "items": [
            "type": "object",
            "properties": [
                "recipeName": [
                    "type": "string",
                    "description": "Name of the recipe",
                    "nullable": false
                ]
            ],
            "required": ["recipeName"]
        ]
    ]
    do {
        let requestBody = GeminiGenerateContentRequestBody(
            contents: [
                .init(
                    parts: [
                        .text("List a few popular cookie recipes."),
                    ]
                )
            ],
            generationConfig: .init(
                responseMimeType: "application/json",
                responseSchema: schema
            )
        )
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash",
            secondsToWait: 60
        )
        for part in response.candidates?.first?.content?.parts ?? [] {
            if case .text(let text) = part {
                print("Gemini sent: \(text)")
            }
        }
        if let usage = response.usageMetadata {
            print(
                """
                Used:
                 \(usage.promptTokenCount ?? 0) prompt tokens
                 \(usage.cachedContentTokenCount ?? 0) cached tokens
                 \(usage.candidatesTokenCount ?? 0) candidate tokens
                 \(usage.totalTokenCount ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create Gemini generate content request: \(error)")
    }
```

### How to use structured ouputs and an image as input with Gemini

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = NSImage(named: "apple_marketing") else {
        print("Could not find an image named 'apple_marketing' in your app assets")
        return
    }

    guard let jpegData = AIProxy.encodeImageAsJpeg(image: image, compressionQuality: 0.4) else {
        print("Could not encode image as Jpeg")
        return
    }

    let schema: [String: AIProxyJSONValue] = [
        "description": "A list of the important points that the document conveys",
        "type": "array",
        "items": [
            "type": "object",
            "properties": [
                "point": [
                    "type": "string",
                    "description": "One of the important points that the document conveys",
                    "nullable": false
                ]
            ],
            "required": ["point"]
        ]
    ]

    let requestBody = GeminiGenerateContentRequestBody(
        contents: [
            .init(
                parts: [
                    .text("Please create the important points of this image"),
                    .inline(
                        data: jpegData,
                        mimeType: "image/jpeg"
                    )
                ]
            )
        ],
        generationConfig: .init(
            responseMimeType: "application/json",
            responseSchema: schema
        ),
        safetySettings: [
            .init(category: .dangerousContent, threshold: .none),
            .init(category: .civicIntegrity, threshold: .none),
            .init(category: .harassment, threshold: .none),
            .init(category: .hateSpeech, threshold: .none),
            .init(category: .sexuallyExplicit, threshold: .none)
        ]
    )

    do {
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash",
            secondsToWait: 60
        )
        for part in response.candidates?.first?.content?.parts ?? [] {
            if case .text(let text) = part {
                print("Gemini sent: \(text)")
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create Gemini generate content request: \(error)")
    }
```

### How to generate an image with Gemini Nano Banana Pro

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = GeminiGenerateContentRequestBody(
        contents: [
            .init(
                parts: [
                    .text(
                        """
                        Hi, can you create a 3d rendered image of a pig with wings and a top hat
                        flying over a happy futuristic scifi city with lots of greenery?
                        """
                    )
                ],
                role: "user"
            )
        ],
        generationConfig: .init(
            imageConfig: .init(
                aspectRatio: "5:4",
            ),
            responseModalities: [
                "Text",
                "Image"
            ]
        ),
        safetySettings: [
            .init(category: .dangerousContent, threshold: .none),
            .init(category: .civicIntegrity, threshold: .none),
            .init(category: .harassment, threshold: .none),
            .init(category: .hateSpeech, threshold: .none),
            .init(category: .sexuallyExplicit, threshold: .none)
        ]
    )

    do {
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-3-pro-image-preview",
            secondsToWait: 120
        )
        for part in response.candidates?.first?.content?.parts ?? [] {
            if case .inlineData(mimeType: let mimeType, base64Data: let base64Data) = part {
                print("Gemini generated inline data with mimetype: \(mimeType) and base64Length: \(base64Data.count)")
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create image using gemini: \(error)")
    }
```


### How to generate an image with Imagen

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = GeminiImagenRequestBody(
        instances: [
            .init(prompt: prompt)
        ],
        parameters: .init(
            personGeneration: .allowAdult,
            safetyLevel: .blockNone,
            sampleCount: 1
        )
    )

    do {
        let response = try await geminiService.makeImagenRequest(
            body: requestBody,
            model: "imagen-3.0-generate-002"
        )
        if let base64Data = response.predictions.first?.bytesBase64Encoded,
           let imageData = Data(base64Encoded: base64Data),
           let image = UIImage(data: imageData) {
            // Do something with image
        } else {
            print("Imagen response did not include base64 image data")
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create Imagen image: \(error)")
    }
```


### How to edit an image with Gemini using the nano banana model

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = UIImage(named: "myImage") else {
        print("Could not find an image named 'myImage' in your app assets")
        return
    }

    guard let pngData = yourUIImage.pngData() else {
        print("Could not get png data from your image")
        return
    }

    let requestBody = GeminiGenerateContentRequestBody(
        contents: [
            .init(
                parts: [
                    .text("Add sparkles to this image"),
                    .inline(
                        data: pngData,
                        mimeType: "image/png"
                    )
                ],
                role: "user"
            )
        ],
        generationConfig: .init(
            responseModalities: [
                "Text",
                "Image"
            ]
        ),
        safetySettings: [
            .init(category: .dangerousContent, threshold: .none),
            .init(category: .civicIntegrity, threshold: .none),
            .init(category: .harassment, threshold: .none),
            .init(category: .hateSpeech, threshold: .none),
            .init(category: .sexuallyExplicit, threshold: .none)
        ]
    )

    do {
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash-image-preview",
            secondsToWait: 120
        )
        for part in response.candidates?.first?.content?.parts ?? [] {
            if case .inlineData(mimeType: let mimeType, base64Data: let base64Data) = part {
                print("Gemini generated inline data with mimetype: \(mimeType) and base64Length: \(base64Data.count)")
                if let imageData = Data(base64Encoded: base64Data),
                   let image = UIImage(data: imageData) {
                     // Do something with image
                }
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create Gemini image edit request: \(error)")
    }
```

### How to use single-speaker TTS with Gemini

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = GeminiGenerateContentRequestBody(
        contents: [
            .init(
                parts: [
                    .text("Hello world")
                ],
                role: "user"
            )
        ],
        generationConfig: .init(
            responseModalities: [
                "AUDIO",
            ],
            speechConfig: .init(
                voiceConfig: .init(
                    prebuiltVoiceConfig: .init(
                        voiceName: .kore
                    )
                )
            )
        ),
        safetySettings: [
            .init(category: .dangerousContent, threshold: .none),
            .init(category: .civicIntegrity, threshold: .none),
            .init(category: .harassment, threshold: .none),
            .init(category: .hateSpeech, threshold: .none),
            .init(category: .sexuallyExplicit, threshold: .none)
        ]
    )

    do {
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash-preview-tts",
            secondsToWait: 300
        )
        for part in response.candidates?.first?.content?.parts ?? [] {
            if case .inlineData(mimeType: let mimeType, base64Data: let base64Data) = part {
                print("Gemini generated inline data with mimetype: \(mimeType) and base64Length: \(base64Data.count)")

                // Do not use a local `let` or `var` for AudioController.
                // You need the lifecycle of the player to live beyond the scope of this function.
                // Instead, use file scope or set the player as a member of a reference type with long life.
                // For example, at the top of this file you may define:
                //
                //   fileprivate var audioController: AudioController? = nil
                //
                // And then use the code below to play the TTS result:
                audioController = try await AudioController(modes: [.playback])
                await audioController?.playPCM16Audio(base64String: base64Data)
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create speech using Gemini: \(error)")
    }
```

### How to use multi-speaker TTS with Gemini

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let geminiService = AIProxy.geminiDirectService(
    //     unprotectedAPIKey: "your-gemini-key"
    // )

    /* Uncomment for all other production use cases */
    // let geminiService = AIProxy.geminiService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = GeminiGenerateContentRequestBody(
        contents: [
            .init(
                parts: [
                    .text("""
                          Joe: How's it going today, Jane?
                          Jane: Not too bad, how about you?
                          """
                    )
                ],
                role: "user"
            )
        ],
        generationConfig: .init(
            responseModalities: [
                "AUDIO",
            ],
            speechConfig: .init(
                multiSpeakerVoiceConfig: .init(
                    speakerVoiceConfigs: [
                        .init(
                            speaker: "Joe",
                            voiceConfig: .init(
                                prebuiltVoiceConfig: .init(
                                    voiceName: .puck
                                )
                            )
                        ),
                        .init(
                            speaker: "Jane",
                            voiceConfig: .init(
                                prebuiltVoiceConfig: .init(
                                    voiceName: .kore
                                )
                            )
                        )
                    ]
                )
            )
        ),
        safetySettings: [
            .init(category: .dangerousContent, threshold: .none),
            .init(category: .civicIntegrity, threshold: .none),
            .init(category: .harassment, threshold: .none),
            .init(category: .hateSpeech, threshold: .none),
            .init(category: .sexuallyExplicit, threshold: .none)
        ]
    )

    do {
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: "gemini-2.5-flash-preview-tts",
            secondsToWait: 300
        )
        for part in response.candidates?.first?.content?.parts ?? [] {
            if case .inlineData(mimeType: let mimeType, base64Data: let base64Data) = part {
                print("Gemini generated inline data with mimetype: \(mimeType) and base64Length: \(base64Data.count)")

                // Do not use a local `let` or `var` for AudioController.
                // You need the lifecycle of the player to live beyond the scope of this function.
                // Instead, use file scope or set the player as a member of a reference type with long life.
                // For example, at the top of this file you may define:
                //
                //   fileprivate var audioController: AudioController? = nil
                //
                // And then use the code below to play the TTS result:
                audioController = try await AudioController(modes: [.playback])
                await audioController?.playPCM16Audio(base64String: base64Data)
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create multi-speaker speech using Gemini: \(error)")
    }
```


***


## Anthropic

### How to make an Anthropic message request

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let anthropicService = AIProxy.anthropicDirectService(
    //     unprotectedAPIKey: "your-anthropic-key"
    // )

    /* Uncomment for all other production use cases */
    // let anthropicService = AIProxy.anthropicService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = AnthropicMessageRequestBody(
        maxTokens: 8192,
        messages: [
            // You can choose your level of sugar here. The most concise option is:
            AnthropicMessageParam(content: "hello world", role: .user)
            //
            // Or, for more flexibility (e.g. adding images, tools, etc.):
            // AnthropicInputMessage(content: [.textBlock("hello world")], role: .user)
            //
            // Or, to fully spell out the call (this helps with Xcode's cmd-click to jump to source):
            // AnthropicInputMessage(
            //     content: .blocks([
            //         .textBlock(AnthropicTextBlockParam(text: "hello world"))
            //     ]),
            //     role: .user
            // )
        ],
        model: "claude-haiku-4-5-20251001",
        system: "You are a friendly assistant"
    )

    do {
        let response = try await anthropicService.messageRequest(
            body: requestBody,
            secondsToWait: 120
        )
        for case let .textBlock(textBlock) in response.content {
            print("Received text from Claude: \(textBlock.text)")
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create an Anthropic message: \(error)")
    }
```


### How to make an Anthropic streaming message request

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let anthropicService = AIProxy.anthropicDirectService(
    //     unprotectedAPIKey: "your-anthropic-key"
    // )

    /* Uncomment for all other production use cases */
    // let anthropicService = AIProxy.anthropicService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = AnthropicMessageRequestBody(
        maxTokens: 1024,
        messages: [
            AnthropicMessageParam(
                content: "Hello world",
                role: .user
            )
        ],
        model: "claude-haiku-4-5-20251001"
    )

    do {
        let stream = try await anthropicService.streamingMessageRequest(
            body: requestBody,
            secondsToWait: 120
        )
        for try await case .contentBlockDelta(let contentBlockDelta) in stream {
            if case .textDelta(let textDelta) = contentBlockDelta.delta {
                print("Received a text delta from Claude: \(textDelta.text)")
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create a streaming Anthropic message: \(error)")
    }
```

### How to make an Anthropic message request with tool calls

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let anthropicService = AIProxy.anthropicDirectService(
    //     unprotectedAPIKey: "your-anthropic-key"
    // )

    /* Uncomment for all other production use cases */
    // let anthropicService = AIProxy.anthropicService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = AnthropicMessageRequestBody(
        maxTokens: 8192,
        messages: [
            AnthropicMessageParam(
                content: "What is Apple's stock price?",
                role: .user
            )
        ],
        model: "claude-haiku-4-5-20251001",
        tools: [
            .customTool(
                AnthropicTool(
                    description: "Call this function when the user wants a stock symbol",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "ticker": [
                                "type": "string",
                                "description": "The stock ticker symbol, e.g. AAPL for Apple Inc."
                            ]
                        ],
                        "required": ["ticker"]
                    ],
                    name: "get_stock_symbol"
                )
            )
        ]
    )

    do {
        let response = try await anthropicService.messageRequest(
            body: requestBody,
            secondsToWait: 120
        )
        for content in response.content {
            switch content {
            case .textBlock(let textBlock):
                print("Received text from Claude: \(textBlock.text)")
            case .toolUseBlock(let toolUseBlock):
                print("Claude wants to call \(toolUseBlock.name) with input: \(toolUseBlock.input)")
            default:
                continue
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create an Anthropic message with tool calls: \(error)")
    }
```

### How to make an Anthropic streaming message request with tool calls

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let anthropicService = AIProxy.anthropicDirectService(
    //     unprotectedAPIKey: "your-anthropic-key"
    // )

    /* Uncomment for all other production use cases */
    // let anthropicService = AIProxy.anthropicService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = AnthropicMessageRequestBody(
        maxTokens: 8192,
        messages: [
            AnthropicMessageParam(
                content: "What is Apple's stock symbol?",
                role: .user
            )
        ],
        model: "claude-haiku-4-5-20251001",
        tools: [
            .customTool(
                AnthropicTool(
                    description: "Call this function when the user wants a stock symbol",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "ticker": [
                                "type": "string",
                                "description": "The stock ticker symbol, e.g. AAPL for Apple Inc."
                            ]
                        ],
                        "required": ["ticker"]
                    ],
                    name: "get_stock_symbol"
                )
            )
        ]
    )

    do {
        let stream = try await anthropicService.streamingMessageRequest(
            body: requestBody,
            secondsToWait: 120
        )
        var toolCallAccumulator = AnthropicToolCallAccumulator()
        for try await event in stream {
            if let (toolName, toolInput) = try toolCallAccumulator.append(event) {
                print("Claude wants to call tool \(toolName) with input \(toolInput)")
            }

            if case .contentBlockDelta(let contentBlockDelta) = event {
                if case .textDelta(let textDelta) = contentBlockDelta.delta {
                    print("Received a text delta from Anthropic: \(textDelta.text)")
                }
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create a streaming Anthropic message with tool calls: \(error)")
    }
```

### How to make an Anthropic streaming message request with fine-grained tool streaming
Fine-grained streaming can improve tool arrival time.
For details, see https://platform.claude.com/docs/en/agents-and-tools/tool-use/fine-grained-tool-streaming

Start with the snippet above, but set `maxTokens` to a large value (e.g. `65536`) and include the following header:

```swift
let stream = try await anthropicService.streamingMessageRequest(
    body: requestBody,
    secondsToWait: 120,
    additionalHeaders: [
        "anthropic-beta": "fine-grained-tool-streaming-2025-05-14"
    ]
)
```

### How to make an Anthropic message request with an image

On macOS, use `NSImage(named:)` in place of `UIImage(named:)`

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let anthropicService = AIProxy.anthropicDirectService(
    //     unprotectedAPIKey: "your-anthropic-key"
    // )

    /* Uncomment for all other production use cases */
    // let anthropicService = AIProxy.anthropicService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = NSImage(named: "my-image") else {
        print("Could not find an image named 'my-image' in your app assets")
        return
    }

    guard let jpegData = AIProxy.encodeImageAsJpeg(image: image, compressionQuality: 0.8) else {
        print("Could not convert image to jpeg")
        return
    }

    let imageBlockParam = AnthropicImageBlockParam(
        source: .base64(data: jpegData.base64EncodedString(), mediaType: .jpeg),
        cacheControl: nil
    )

    let requestBody = AnthropicMessageRequestBody(
        maxTokens: 8192,
        messages: [
            AnthropicMessageParam(
                content: [
                    .textBlock("Provide a very short description of this image"),
                    .imageBlock(imageBlockParam),
                ],
                role: .user
            )
        ],
        model: "claude-haiku-4-5-20251001",
    )

    do {
        let response = try await anthropicService.messageRequest(
            body: requestBody,
            secondsToWait: 120
        )
        for case let .textBlock(textBlock) in response.content {
            print("Received text from Claude: \(textBlock.text)")
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create an Anthropic message with image input: \(error)")
    }
```


### How to make an Anthropic message request with a PDF

This snippet includes a pdf `mydocument.pdf` in the Anthropic request. Adjust the filename to
match the pdf included in your Xcode project. The snippet expects the pdf in the app bundle.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let anthropicService = AIProxy.anthropicDirectService(
    //     unprotectedAPIKey: "your-anthropic-key"
    // )

    /* Uncomment for all other production use cases */
    // let anthropicService = AIProxy.anthropicService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let pdfFileURL = Bundle.main.url(forResource: "mydocument", withExtension: "pdf"),
          let pdfData = try? Data(contentsOf: pdfFileURL)
    else {
        print("Drop mydocument.pdf into your Xcode project first.")
        return
    }

    let documentBlockParam = AnthropicDocumentBlockParam(
        source: .base64PDF(AnthropicBase64PDFSource(data: pdfData.base64EncodedString()))
    )

    let requestBody = AnthropicMessageRequestBody(
        maxTokens: 8192,
        messages: [
            AnthropicMessageParam(
                content: [
                    .textBlock("Provide a very short description of this pdf"),
                    .documentBlock(documentBlockParam),
                ],
                role: .user
            )
        ],
        model: "claude-haiku-4-5-20251001"
    )

    do {
        let response = try await anthropicService.messageRequest(
            body: requestBody,
            secondsToWait: 120
        )
        for case let .textBlock(textBlock) in response.content {
            print("Received text from Claude: \(textBlock.text)")
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create an Anthropic message with pdf input: \(error)")
    }
```


### How to make an Anthropic streaming message request with a PDF

This snippet includes a pdf `mydocument.pdf` in the Anthropic request. Adjust the filename to
match the pdf included in your Xcode project. The snippet expects the pdf in the app bundle.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let anthropicService = AIProxy.anthropicDirectService(
    //     unprotectedAPIKey: "your-anthropic-key"
    // )

    /* Uncomment for all other production use cases */
    // let anthropicService = AIProxy.anthropicService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let pdfFileURL = Bundle.main.url(forResource: "mydocument", withExtension: "pdf"),
          let pdfData = try? Data(contentsOf: pdfFileURL)
    else {
        print("Drop mydocument.pdf into your Xcode project first.")
        return
    }

    let documentBlockParam = AnthropicDocumentBlockParam(
        source: .base64PDF(AnthropicBase64PDFSource(data: pdfData.base64EncodedString()))
    )

    let requestBody = AnthropicMessageRequestBody(
        maxTokens: 8192,
        messages: [
            AnthropicMessageParam(
                content: [
                    .textBlock("Provide a very short description of this pdf"),
                    .documentBlock(documentBlockParam),
                ],
                role: .user
            )
        ],
        model: "claude-haiku-4-5-20251001"
    )

    do {
        let stream = try await anthropicService.streamingMessageRequest(
            body: requestBody,
            secondsToWait: 120
        )
        for try await case .contentBlockDelta(let contentBlockDelta) in stream {
            if case .textDelta(let textDelta) = contentBlockDelta.delta {
                print("Received a text delta from Anthropic: \(textDelta.text)")
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create a streaming Anthropic message with pdf input: \(error)")
    }
```

### How to create an Anthropic request with a cached system prompt

For pricing, see: https://platform.claude.com/docs/en/build-with-claude/prompt-caching#pricing 

```swift
    let requestBody = AnthropicMessageRequestBody(
        maxTokens: 1024,
        messages: [ /* snip */ ],
        model: "claude-haiku-4-5-20251001",
        system: .blocks([
            AnthropicSystemTextBlockParam(
                text: "This is a very long prompt",
                cacheControl: AnthropicCacheControlEphemeral(ttl: .oneHour)
            )
        ])
    )
```

### How to make requests to Anthropic on Azure

1. Use the same snippets as above, but add the following to your `messageRequest` or `streamingMessageRequest` args:

```swift
additionalHeaders: [
    "aiproxy-key-format": "x-api-key: {{key}}"
]
```

2. In the AIProxy dashboard, configure your service to use the base URL of your Azure deployment *up to but not including* the `/v1/messages` path component.


***


## Stability.ai

### How to generate an image with Stability.ai

In the snippet below, replace NSImage with UIImage if you are building on iOS.
For a SwiftUI example, see [this gist](https://gist.github.com/lzell/a878b787f24cc0dd87a31f4dceccd092)

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let stabilityService = AIProxy.stabilityDirectService(
    //     unprotectedAPIKey: "your-stability-key"
    // )

    /* Uncomment for all other production use cases */
    // let service = AIProxy.stabilityAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let body = StabilityAIUltraRequestBody(prompt: "Lighthouse on a cliff overlooking the ocean")
        let response = try await service.ultraRequest(body: body)
        let image = NSImage(data: response.imageData)
        // Do something with `image`
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not generate an image with StabilityAI: \(error)")
    }
```

***

## DeepL

### How to create translations using DeepL

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let deepLService = AIProxy.deepLDirectService(
    //     unprotectedAPIKey: "your-deepL-key"
    // )

    /* Uncomment for all other production use cases */
    // let service = AIProxy.deepLService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let body = DeepLTranslateRequestBody(targetLang: "ES", text: ["hello world"])
        let response = try await service.translateRequest(body: body)
        // Do something with `response.translations`
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create DeepL translation: \(error)")
    }

***

## TogetherAI

### How to create a non-streaming chat completion with TogetherAI

See the [TogetherAI model list](https://docs.together.ai/docs/chat-models) for available
options to pass as the `model` argument:

    import AIProxy

    /* Uncomment for BYOK use cases */
    // let togetherAIService = AIProxy.togetherAIDirectService(
    //     unprotectedAPIKey: "your-togetherAI-key"
    // )

    /* Uncomment for all other production use cases */
    // let togetherAIService = AIProxy.togetherAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let requestBody = TogetherAIChatCompletionRequestBody(
            messages: [TogetherAIMessage(content: "Hello world", role: .user)],
            model: "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo"
        )
        let response = try await togetherAIService.chatCompletionRequest(body: requestBody)
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create TogetherAI chat completion: \(error)")
    }


### How to create a streaming chat completion with TogetherAI

See the [TogetherAI model list](https://docs.together.ai/docs/chat-models) for available
options to pass as the `model` argument:

    import AIProxy

    /* Uncomment for BYOK use cases */
    // let togetherAIService = AIProxy.togetherAIDirectService(
    //     unprotectedAPIKey: "your-togetherAI-key"
    // )

    /* Uncomment for all other production use cases */
    // let togetherAIService = AIProxy.togetherAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let requestBody = TogetherAIChatCompletionRequestBody(
            messages: [TogetherAIMessage(content: "Hello world", role: .user)],
            model: "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo"
        )
        let stream = try await togetherAIService.streamingChatCompletionRequest(body: requestBody)
        for try await chunk in stream {
            print(chunk.choices.first?.delta.content ?? "")
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create TogetherAI streaming chat completion: \(error)")
    }


### How to create a JSON response with TogetherAI

JSON mode is handy for enforcing that the model returns JSON in a structure that your
application expects. You specify the contract using `schema` below. Note that only some models
support JSON mode. See [this guide](https://docs.together.ai/docs/json-mode) for a list.

    import AIProxy

    /* Uncomment for BYOK use cases */
    // let togetherAIService = AIProxy.togetherAIDirectService(
    //     unprotectedAPIKey: "your-togetherAI-key"
    // )

    /* Uncomment for all other production use cases */
    // let togetherAIService = AIProxy.togetherAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let schema: [String: AIProxyJSONValue] = [
            "type": "object",
            "properties": [
                "colors": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": [
                                "type": "string",
                                "description": "A descriptive name to give the color"
                            ],
                            "hex_code": [
                                "type": "string",
                                "description": "The hex code of the color"
                            ]
                        ],
                        "required": ["name", "hex_code"],
                        "additionalProperties": false
                    ]
                ]
            ],
            "required": ["colors"],
            "additionalProperties": false
        ]
        let requestBody = TogetherAIChatCompletionRequestBody(
            messages: [
                TogetherAIMessage(
                    content: "You are a helpful assistant that answers in JSON",
                    role: .system
                ),
                TogetherAIMessage(
                    content: "Create a peaches and cream color palette",
                    role: .user
                )
            ],
            model: "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo",
            responseFormat: .json(schema: schema)
        )
        let response = try await togetherAIService.chatCompletionRequest(body: requestBody)
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create TogetherAI JSON chat completion: \(error)")
    }


### How to make a tool call request with Llama and TogetherAI

If you need this use case, please open a github issue. We don't currently get the tool call
result out of the response!

This example is a Swift port of [this guide](https://docs.together.ai/docs/llama-3-function-calling):

    import AIProxy

    /* Uncomment for BYOK use cases */
    // let togetherAIService = AIProxy.togetherAIDirectService(
    //     unprotectedAPIKey: "your-togetherAI-key"
    // )

    /* Uncomment for all other production use cases */
    // let togetherAIService = AIProxy.togetherAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let function = TogetherAIFunction(
            description: "Call this when the user wants the weather",
            name: "get_weather",
            parameters: [
                "type": "object",
                "properties": [
                    "location": [
                        "type": "string",
                        "description": "The city and state, e.g. San Francisco, CA",
                    ],
                    "num_days": [
                        "type": "integer",
                        "description": "The number of days to get the forecast for",
                    ],
                ],
                "required": ["location", "num_days"],
            ]
        )

        let toolPrompt = """
        You have access to the following functions:

        Use the function '\(function.name)' to '\(function.description)':
        \(try function.serialize())

        If you choose to call a function ONLY reply in the following format with no prefix or suffix:

        <function=example_function_name>{{\"example_name\": \"example_value\"}}</function>

        Reminder:
        - Function calls MUST follow the specified format, start with <function= and end with </function>
        - Required parameters MUST be specified
        - Only call one function at a time
        - Put the entire function call reply on one line
        - If there is no function call available, answer the question like normal with your current knowledge and do not tell the user about function calls

        """

        let requestBody = TogetherAIChatCompletionRequestBody(
            messages: [
                TogetherAIMessage(
                    content: toolPrompt,
                    role: .system
                ),
                TogetherAIMessage(
                    content: "What's the weather like in Tokyo over the next few days?",
                    role: .user
                )
            ],
            model: "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo",
            temperature: 0,
            tools: [
                TogetherAITool(function: function)
            ]
        )
        let response = try await togetherAIService.chatCompletionRequest(body: requestBody)
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create TogetherAI llama 3.1 tool completion: \(error)")
    }


***


## Replicate

### How to generate a Flux-Schnell image by Black Forest Labs, using Replicate

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let input = ReplicateFluxSchnellInputSchema(
            prompt: "Monument valley, Utah"
        )
        let urls = try await replicateService.createFluxSchnellImages(
            input: input,
            secondsToWait: 30
        )
        print("Done creating Flux-Schnell images: ", urls)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        // You may want to catch additional Foundation errors and pop the appropriate UI
        // to the user. See "How to catch Foundation errors for specific conditions" here:
        // https://www.aiproxy.com/docs/integration-options.html
        print("Could not create Flux-Schnell image: \(error)")
    }
```


See the full range of controls for generating an image by viewing `ReplicateFluxSchnellInputSchema.swift`


### How to generate a Flux-Dev image by Black Forest Labs, using Replicate

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let input = ReplicateFluxDevInputSchema(
            prompt: "Monument valley, Utah. High res",
            goFast: false
        )
        let urls = try await replicateService.createFluxDevImages(
            input: input,
            secondsToWait: 30
        )
        print("Done creating Flux-Dev images: ", urls)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        // You may want to catch additional Foundation errors and pop the appropriate UI
        // to the user. See "How to catch Foundation errors for specific conditions" here:
        // https://www.aiproxy.com/docs/integration-options.html
        print("Could not create Flux-Dev image: \(error)")
    }
```


See the full range of controls for generating an image by viewing `ReplicateFluxDevInputSchema.swift`


### How to generate a Flux-Pro image by Black Forest Labs, using Replicate

This snippet generates a version 1.1 image. If you would like to generate version 1, make the
following substitutions:

- `ReplicateFluxProInputSchema_v1_1` -> `ReplicateFluxProInputSchema`
- `createFluxProImage_v1_1` -> `createFluxProImage`

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let input = ReplicateFluxProInputSchema_v1_1(
            prompt: "Monument valley, Utah. High res"
            promptUpsampling: true
        )
        let url = try await replicateService.createFluxProImage_v1_1(
            input: input,
            secondsToWait: 60
        )
        print("Done creating Flux-Pro 1.1 image: ", url)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        // You may want to catch additional Foundation errors and pop the appropriate UI
        // to the user. See "How to catch Foundation errors for specific conditions" here:
        // https://www.aiproxy.com/docs/integration-options.html
        print("Could not create Flux-Pro 1.1 image: \(error)")
    }
```

See the full range of controls for generating an image by viewing `ReplicateFluxProInputSchema_v1_1.swift`


### How to generate a Flux-PuLID image using Replicate

On macOS, use `NSImage(named:)` in place of `UIImage(named:)`

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = NSImage(named: "face") else {
        print("Could not find an image named 'face' in your app assets")
        return
    }

    guard let imageURL = AIProxy.encodeImageAsURL(
        image: image,
        compressionQuality: 0.8
    ) else {
        print("Could not convert image to a local data URI")
        return
    }

    do {
        let input = ReplicateFluxPulidInputSchema(
            mainFaceImage: imageURL,
            prompt: "smiling man holding sign with glowing green text 'PuLID for FLUX'",
            numOutputs: 1,
            startStep: 4
        )
        let urls = try await replicateService.createFluxPuLIDImages(
            input: input,
            secondsToWait: 60
        )
        print("Done creating Flux-PuLID image: ", urls)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        // You may want to catch additional Foundation errors and pop the appropriate UI
        // to the user. See "How to catch Foundation errors for specific conditions" here:
        // https://www.aiproxy.com/docs/integration-options.html
        print("Could not create Flux-Pulid images: \(error)")
    }
```


See the full range of controls for generating an image by viewing `ReplicateFluxPulidInputSchema.swift`


### How to generate an image from a reference image using Flux ControlNet on Replicate

There are many controls to play with for this use case. Please see
`ReplicateFluxDevControlNetInputSchema.swift` for the full range of controls.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let input = ReplicateFluxDevControlNetInputSchema(
            controlImage: URL(string: "https://example.com/your/image")!,
            prompt: "a cyberpunk with natural greys and whites and browns",
            controlStrength: 0.4
        )
        let output = try await replicateService.createFluxDevControlNetImages(
            input: input,
            secondsToWait: 60
        )
        print("Done creating Flux-ControlNet image: ", output)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        // You may want to catch additional Foundation errors and pop the appropriate UI
        // to the user. See "How to catch Foundation errors for specific conditions" here:
        // https://www.aiproxy.com/docs/integration-options.html
        print("Could not create Flux-ControlNet image: \(error)")
    }
```


### How to generate an SDXL image by StabilityAI, using Replicate

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let input = ReplicateSDXLInputSchema(
            prompt: "Monument valley, Utah"
        )
        let urls = try await replicateService.createSDXLImages(
            input: input,
            secondsToWait: 2
        )
        print("Done creating SDXL images: ", urls)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        // You may want to catch additional Foundation errors and pop the appropriate UI
        // to the user. See "How to catch Foundation errors for specific conditions" here:
        // https://www.aiproxy.com/docs/integration-options.html
        print("Could not create SDXL image: \(error)")
    }
```

See the full range of controls for generating an image by viewing `ReplicateSDXLInputSchema.swift`


### How to generate an SDXL Fresh Ink image by fofr, using Replicate

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let input = ReplicateSDXLFreshInkInputSchema(
            prompt: "A fresh ink TOK tattoo of monument valley, Utah",
            negativePrompt: "ugly, broken, distorted"
        )
        let urls = try await replicateService.createSDXLFreshInkImages(
            input: input,
            secondsToWait: 60
        )
        print("Done creating SDXL Fresh Ink images: ", urls)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        // You may want to catch additional Foundation errors and pop the appropriate UI
        // to the user. See "How to catch Foundation errors for specific conditions" here:
        // https://www.aiproxy.com/docs/integration-options.html
        print("Could not create SDXL Fresh Ink images: \(error)")
    }
```

See the full range of controls for generating an image by viewing `ReplicateSDXLFreshInkInputSchema.swift`

### How to call DeepSeek's 7B vision model on replicate

Add a file called 'my-image.jpg' to Xcode app assets. Then run this snippet:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = NSImage(named: "my-image") else {
        print("Could not find an image named 'my-image' in your app assets")
        return
    }

    guard let imageURL = AIProxy.encodeImageAsURL(image: image, compressionQuality: 0.4) else {
        print("Could not encode image as a data URI")
        return
    }

    do {
        let input = ReplicateDeepSeekVL7BInputSchema(
            image: imageURL,
            prompt: "What are the colors in this pic"
        )
        let description = try await replicateService.runDeepSeekVL7B(input: input, secondsToWait: 300)
        print("Done getting descriptions from DeepSeekVL7B: ", description)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        // You may want to catch additional Foundation errors and pop the appropriate UI
        // to the user. See "How to catch Foundation errors for specific conditions" here:
        // https://www.aiproxy.com/docs/integration-options.html
        print("Could not use deepseek vision on replicate: \(error)")
    }
```


### How to call your own models on Replicate.

Look in the `ReplicateService+Convenience.swift` file for inspiration on how to do this.

1. Generate the Encodable representation of your input schema. Take a look at any of the input
   schemas used in `ReplicateService+Convenience.swift` for inspiration. Find the schema format
   that you should conform to using replicate's web dashboard and tapping through `Your Model >
   API > Schema > Input Schema`

2. Generate the Decodable representation of your output schema. The output schema is defined on
   replicate's site at `Your Model > API > Schema > Output Schema`. I find that unfortunately
   these schemas are not always accurate, so sometimes you have to look at the network response
   manually. For simple cases, a typealias will do (for example, if the output schema is just a
   string or an array of strings). Look at `ReplicateFluxOutputSchema.swift` for inspiration.
   If you need help doing this, please reach out.

3. Call `replicateService.runOfficialModel` or `replicateService.runCommunityModel`. Community
   models have a `version` while official models do not.

4. Call `replicateService.getPredictionOutput` on the result from step 3.

You'll need to change `YourInputSchema`, `YourOutputSchema` and `your-model-version` in this
snippet:


```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let input = YourInputSchema(
            prompt: "Monument valley, Utah"
        )
        let prediction: ReplicatePrediction<YourOutputSchema> = try await replicateService.runCommunityModel( /* or runOfficialModel */
            version: "your-model-version",
            input: input,
            secondsToWait: secondsToWait
        )
        let output: YourOutputSchema = try await replicateService.getPredictionOutput(prediction)

        // Do something with output

    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        // You may want to catch additional Foundation errors and pop the appropriate UI
        // to the user. See "How to catch Foundation errors for specific conditions" here:
        // https://www.aiproxy.com/docs/integration-options.html
        print("Could not run replicate model: \(error)")
    }
```

### How to upload a file to Replicate's CDN

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = NSImage(named: "face") else {
        print("Drop face.jpeg into Assets first")
        return
    }

    guard let imageData = AIProxy.encodeImageAsJpeg(image: image, compressionQuality: 0.5) else {
        print("Could not encode the image as jpeg")
        return
    }

    do {
        let fileUploadResponse = try await replicateService.uploadFile(
            contents: imageData,
            contentType: "image/jpeg",
            name: "face.jpg"
        )
        print("""
              Image uploaded. Find it at \(fileUploadResponse.urls.get)
              You can use this file until \(fileUploadResponse.expiresAt ?? "")
              """)

    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        // You may want to catch additional Foundation errors and pop the appropriate UI
        // to the user. See "How to catch Foundation errors for specific conditions" here:
        // https://www.aiproxy.com/docs/integration-options.html
        print("Could not upload file to replicate: \(error)")
    }
```

### How to create a replicate model for your own Flux fine tune

Replace `<your-account>`:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let modelURL = try await replicateService.createModel(
            owner: "<your-account>",
            name: "my-model",
            description: "My great model",
            hardware: "gpu-t4",
            visibility: .private
        )
        print("Your model is at \(modelURL)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create replicate model: \(error)")
    }
```

### How to upload training data for your own Flux fine tune

Create a zip file called `training.zip` and drop it in your Xcode assets.
See the "Prepare your training data" section of [this guide](https://replicate.com/blog/fine-tune-flux)
for tips on what to include in the zip file. Then run:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let trainingData = NSDataAsset(name: "training") else {
        print("""
              Drop training.zip file into Assets first.
              See the 'Prepare your training data' of this guide:
              https://replicate.com/blog/fine-tune-flux
              """)
        return
    }

    do {
        let fileUploadResponse = try await replicateService.uploadTrainingZipFile(
            zipData: trainingData.data,
            name: "training.zip"
        )
        print("""
              Training file uploaded. Find it at \(fileUploadResponse.urls.get)
              You you can train with this file until \(fileUploadResponse.expiresAt ?? "")
              """)

    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not upload file to replicate: \(error)")
    }
```

### How to train a flux fine-tune

Use the `<training-url>` returned from the snippet above.
Use the `<model-name>` that you used from the snippet above that.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        // You should experiment with the settings in `ReplicateFluxTrainingInput.swift` to
        // find what works best for your use case.
        //
        // The `layersToOptimizeRegex` argument here speeds training and works well for faces.
        // You could could optionally remove that argument to see if the final trained model
        // works better for your user case.
        let trainingInput = ReplicateFluxTrainingInput(
            inputImages: URL(string: "<training-url>")!,
            layersToOptimizeRegex: "transformer.single_transformer_blocks.(7|12|16|20).proj_out",
            steps: 200,
            triggerWord: "face"
        )
        let reqBody = ReplicateTrainingRequestBody(destination: "<model-owner>/<model-name>", input: trainingInput)


        // Find valid version numbers here: https://replicate.com/ostris/flux-dev-lora-trainer/train
        let training = try await replicateService.createTraining(
            modelOwner: "ostris",
            modelName: "flux-dev-lora-trainer",
            versionID: "d995297071a44dcb72244e6c19462111649ec86a9646c32df56daa7f14801944",
            body: reqBody
        )
        print("Get training status at: \(training.urls?.get?.absoluteString ?? "unknown")")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create replicate training: \(error)")
    }
```

### How to poll the flux fine-tune for training complete

Use the `<url>` that is returned from the snippet above.

```swift    
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    // This URL comes from the output of the sample above
    let url = URL(string: "<url>")!

    do {
        let training = try await replicateService.pollForTrainingCompletion(
            url: url,
            pollAttempts: 100,
            secondsBetweenPollAttempts: 10
        )
        print("""
              Flux training status: \(training.status?.rawValue ?? "unknown")
              Your model version is: \(training.output?.version ?? "unknown")
              """)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not poll for the replicate training: \(error)")
    }
```

### How to generate images with your own flux fine-tune

Use the `<version>` string that was returned from the snippet above, but do not include the
model owner and model name in the string.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let input = ReplicateFluxFineTuneInputSchema(
        prompt: "an oil painting of my face on a blimp",
        model: .dev,
        numInferenceSteps: 28  // Replicate recommends around 28 steps for `.dev` and 4 for `.schnell`
    )

    do {
        let predictionResponse = try await replicateService.createPrediction(
            version: "<version>",
            input: input,
            output: ReplicatePrediction<[URL]>.self
        )

        let predictionOutput: [URL] = try await replicateService.pollForPredictionOutput(
            predictionResponse: predictionResponse,
            pollAttempts: 30,
            secondsBetweenPollAttempts: 5
        )
        print("Done creating predictionOutput: \(predictionOutput)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create replicate prediction: \(error)")
    }
```

### How to edit images with Flux Kontext Max on Replicate

```
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = NSImage(named: "my_image") else {
        print("Could not find an image named 'my_image' in your app assets")
        return
    }

    guard let imageURL = AIProxy.encodeImageAsURL(image: image, compressionQuality: 0.5) else {
        print("Could not encode image as a data URI")
        return
    }

    do {
        let input = ReplicateFluxKontextInputSchema(
            inputImage: imageURL,
            prompt: "Make the letters 3D, floating in space above Monument Valley, Utah"
        )
        let url = try await replicateService.createFluxKontextMaxImage(
            input: input,
            secondsToWait: 120
        )
        print("Done creating Flux Kontext Max image: ", url)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create Flux Kontext Max image: \(error)")
    }
```

### How to edit images with Flux Kontext Pro on Replicate

```
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let replicateService = AIProxy.replicateDirectService(
    //     unprotectedAPIKey: "your-replicate-key"
    // )

    /* Uncomment for all other production use cases */
    // let replicateService = AIProxy.replicateService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = NSImage(named: "my_image") else {
        print("Could not find an image named 'my_image' in your app assets")
        return
    }

    guard let imageURL = AIProxy.encodeImageAsURL(image: image, compressionQuality: 0.5) else {
        print("Could not encode image as a data URI")
        return
    }

    do {
        let input = ReplicateFluxKontextInputSchema(
            inputImage: imageURL,
            prompt: "Make the letters 3D, floating in space above Monument Valley, Utah"
        )
        let url = try await replicateService.createFluxKontextProImage(
            input: input,
            secondsToWait: 120
        )
        print("Done creating Flux Kontext Pro image: ", url)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create Flux Kontext Pro image: \(error)")
    }
```

***


## ElevenLabs

### How to use ElevenLabs for text-to-speech

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let elevenLabsService = AIProxy.elevenLabsDirectService(
    //     unprotectedAPIKey: "your-elevenLabs-key"
    // )

    /* Uncomment for all other production use cases */
    // let elevenLabsService = AIProxy.elevenLabsService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let body = ElevenLabsTTSRequestBody(
            text: "Hello world"
        )
        let mpegData = try await elevenLabsService.ttsRequest(
            voiceID: "EXAVITQu4vr4xnSDxMaL",
            body: body
        )

        // Do not use a local `let` or `var` for AVAudioPlayer.
        // You need the lifecycle of the player to live beyond the scope of this function.
        // Instead, use file scope or set the player as a member of a reference type with long life.
        // For example, at the top of this file you may define:
        //
        //   fileprivate var audioPlayer: AVAudioPlayer? = nil
        //
        // And then use the code below to play the TTS result:
        audioPlayer = try AVAudioPlayer(data: mpegData)
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create ElevenLabs TTS audio: \(error)")
    }
```

- See the full range of TTS controls by viewing `ElevenLabsTTSRequestBody.swift`.
- See https://api.elevenlabs.io/v1/voices for the IDs that you can pass to `voiceID`.
- To get timing information of the spoken text, use `elevenLabsService.ttsRequestWithTimestamps`:

```swift
let res = try await elevenLabsService.ttsRequestWithTimestamps(
    voiceID: "EXAVITQu4vr4xnSDxMaL",
    body: body,
    secondsToWait: 120
)
// Timing information is available as `res.alignment` and `res.normalizedAlignment`
// Audio to pass to the AVAudioPlayer is available as `res.audioData`
```

### How to use ElevenLabs for streaming text-to-speech

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let elevenLabsService = AIProxy.elevenLabsDirectService(
    //     unprotectedAPIKey: "your-elevenLabs-key"
    // )

    /* Uncomment for all other production use cases */
    // let elevenLabsService = AIProxy.elevenLabsService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let body = ElevenLabsTTSRequestBody(text: "Hello world")

    do {
        // Do not use a local `let` or `var` for AudioController.
        // You need the lifecycle of the player to live beyond the scope of this function.
        //
        // Use file scope or set the player as a member of a reference type with long life.
        // For example, at the top of this file you may define:
        //
        //   fileprivate var audioController: AudioController? = nil
        //
        // and then use the code below to stream the TTS result.
        //
        // For an improved user experience, try to opportunistically create the AudioController
        // before the user needs it (for example, when the user starts a flow that may use audio).
        // That way the player is warmed by the time ElevenLabs streams the first bit of audio for playback.
        audioController = try await AudioController(modes: [.playback])

        let stream = try await elevenLabsService.streamingTTSRequest(
            voiceID: "EXAVITQu4vr4xnSDxMaL",
            body: body,
            secondsToWait: 60
        )

        for await chunk in stream {
            await audioController?.playPCM16Audio(data: chunk)
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create ElevenLabs TTS streaming audio: \(error)")
    }
```

- See the full range of TTS controls by viewing `ElevenLabsTTSRequestBody.swift`.
- See https://api.elevenlabs.io/v1/voices for the IDs that you can pass to `voiceID`.
- To get timing information of the spoken text, use `elevenLabsService.streamingTTSWithTimestampsRequest`:

```swift
let stream = try await elevenLabsService.streamingTTSWithTimestampsRequest(
    voiceID: "EXAVITQu4vr4xnSDxMaL",
    body: body,
    secondsToWait: 120
)

for try await chunk in stream {
    // Timing information is available as `chunk.alignment` and `chunk.normalizedAlignment`
    // Audio to pass to the AVAudioPlayer is available as `chunk.audioData`
}
```

### How to use ElevenLabs for speech-to-speech

1. Record an audio file in quicktime and save it as "helloworld.m4a"
2. Add the audio file to your Xcode project. Make sure it's included in your target: select your audio file in the project tree, type `cmd-opt-0` to open the inspect panel, and view `Target Membership`
3. Run this snippet:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let elevenLabsService = AIProxy.elevenLabsDirectService(
    //     unprotectedAPIKey: "your-elevenLabs-key"
    // )

    /* Uncomment for all other production use cases */
    // let elevenLabsService = AIProxy.elevenLabsService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let localAudioURL = Bundle.main.url(forResource: "helloworld", withExtension: "m4a") else {
        print("Could not find an audio file named helloworld.m4a in your app bundle")
        return
    }

    do {
        let body = ElevenLabsSpeechToSpeechRequestBody(
            audio: try Data(contentsOf: localAudioURL),
            modelID: "eleven_english_sts_v2",
            removeBackgroundNoise: true
        )
        let mpegData = try await elevenLabsService.speechToSpeechRequest(
            voiceID: "EXAVITQu4vr4xnSDxMaL",
            body: body
        )

        // Do not use a local `let` or `var` for AVAudioPlayer.
        // You need the lifecycle of the player to live beyond the scope of this function.
        // Instead, use file scope or set the player as a member of a reference type with long life.
        // For example, at the top of this file you may define:
        //
        //   fileprivate var audioPlayer: AVAudioPlayer? = nil
        //
        // And then use the code below to play the TTS result:
        audioPlayer = try AVAudioPlayer(data: mpegData)
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create ElevenLabs STS audio: \(error)")
    }
```

### How to use ElevenLabs for speech-to-text

1. Record an audio file in quicktime and save it as "helloworld.m4a"
2. Add the audio file to your Xcode project. Make sure it's included in your target: select your audio file in the project tree, type `cmd-opt-0` to open the inspect panel, and view `Target Membership`
3. Run this snippet:


```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let elevenLabsService = AIProxy.elevenLabsDirectService(
    //     unprotectedAPIKey: "your-elevenLabs-key"
    // )

    /* Uncomment for all other production use cases */
    // let elevenLabsService = AIProxy.elevenLabsService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let localAudioURL = Bundle.main.url(forResource: "helloworld", withExtension: "m4a") else {
        print("Could not find an audio file named helloworld.m4a in your app bundle")
        return
    }

    do {
        let body = ElevenLabsSpeechToTextRequestBody(
            modelID: .scribeV1,
            file: try Data(contentsOf: localAudioURL),
        )
        let res = try await elevenLabsService.speechToTextRequest(
            body: body
        )
        print("ElevenLabs transcribed: \(res.text ?? "")")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create ElevenLabs STT audio: \(error)")
    }
```

***


## Fal

### How to generate a FastSDXL image using Fal

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let falService = AIProxy.falDirectService(
    //     unprotectedAPIKey: "your-fal-key"
    // )

    /* Uncomment for all other production use cases */
    // let falService = AIProxy.falService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let input = FalFastSDXLInputSchema(
        prompt: "Yosemite Valley",
        enableSafetyChecker: false
    )
    do {
        let output = try await falService.createFastSDXLImage(input: input)
        print("""
              The first output image is at \(output.images?.first?.url?.absoluteString ?? "")
              It took \(output.timings?.inference ?? Double.nan) seconds to generate.
              """)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create Fal SDXL image: \(error)")
    }
```

See the full range of controls for generating an image by viewing `FalFastSDXLInputSchema.swift`


### How to use the fashn/tryon model on Fal

The `garmentImage` and `modelImage` arguments may be:

1. A remote URL to the image hosted on a public site
2. A local data URL that you construct using `AIProxy.encodeImageAsURL`

    ```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let falService = AIProxy.falDirectService(
    //     unprotectedAPIKey: "your-fal-key"
    // )

    /* Uncomment for all other production use cases */
    // let falService = AIProxy.falService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let garmentImage = NSImage(named: "garment-image"),
          let garmentImageURL = AIProxy.encodeImageAsURL(image: garmentImage
                                                         compressionQuality: 0.6) else {
        print("Could not find an image named 'garment-image' in your app assets")
        return
    }

    guard let modelImage = NSImage(named: "model-image"),
          let modelImageURL = AIProxy.encodeImageAsURL(image: modelImage,
                                                       compressionQuality: 0.6) else {
        print("Could not find an image named 'model-image' in your app assets")
        return
    }

    let input = FalTryonInputSchema(
        category: .tops,
        garmentImage: garmentImageURL,
        modelImage: modelImageURL
    )
    do {
        let output = try await falService.createTryonImage(input: input)
        print("Tryon image is available at: \(output.images.first?.url.absoluteString ?? "No URL")")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create fashn/tryon image on Fal: \(error)")
    }
    ```


### How to train Flux on your own images using Fal

#### Upload training data to Fal

Your training data must be a zip file of images. You can either pull the zip from assets (what
I do here), or construct the zip in memory:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let falService = AIProxy.falDirectService(
    //     unprotectedAPIKey: "your-fal-key"
    // )

    /* Uncomment for all other production use cases */
    // let falService = AIProxy.falService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    // Get the images to train with:
    guard let trainingData = NSDataAsset(name: "training") else {
        print("Drop training.zip file into Assets first")
        return
    }

    do {
        let url = try await falService.uploadTrainingZipFile(
            zipData: trainingData.data,
            name: "training.zip"
        )
        print("Training file uploaded. Find it at \(url.absoluteString)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not upload file to Fal: \(error)")
    }
```

#### Train `fal-ai/flux-lora-fast-training` using your uploaded data

Using the URL returned in the step above:

```swift
    let input = FalFluxLoRAFastTrainingInputSchema(
        imagesDataURL: <url-from-step-above>
        triggerWord: "face"
    )
    do {
        let output = try await falService.createFluxLoRAFastTraining(input: input)
        print("""
              Fal's Flux LoRA fast trainer is complete.
              Your weights are at: \(output.diffusersLoraFile?.url?.absoluteString ?? "")
              """)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create Fal Flux training: \(error)")
    }
```

See `FalFluxLoRAFastTrainingInputSchema.swift` for the full range of training controls.

#### Run inference on your trained model

Using the LoRA URL returned in the step above:

```swift
    let inputSchema = FalFluxLoRAInputSchema(
        prompt: "face on a blimp over Monument Valley, Utah",
        loras: [
            .init(
                path: <lora-url-from-step-above>
                scale: 0.9
            )
        ],
        numImages: 2,
        outputFormat: .jpeg
    )
    do {
        let output = try await falService.createFluxLoRAImage(input: inputSchema)
        print("""
              Fal's Flux LoRA inference is complete.
              Your images are at: \(output.images?.compactMap {$0.url?.absoluteString} ?? [])
              """)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create Fal LoRA image: \(error)")
    }
```

See `FalFluxLoRAInputSchema.swift` for the full range of inference controls

#### How to edit an image using Flux Kontext Pro on Fal


```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let falService = AIProxy.falDirectService(
    //     unprotectedAPIKey: "your-fal-key"
    // )

    /* Uncomment for all other production use cases */
    // let falService = AIProxy.falService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = NSImage(named: "myImage") else {
        print("Could not find an image named 'myImage' in your app assets")
        return
    }

    guard let imageURL = AIProxy.encodeImageAsURL(image: image, compressionQuality: 0.5) else {
        print("Could not encode image as a data URL")
        return
    }

    let input = FalFluxProKontextInputSchema(
        imageURL: imageURL,
        prompt: "Make the letters 3D, floating in space above Monument Valley, Utah",
    )

    do {
        let output = try await falService.createFluxProKontextImage(
            input: input,
            secondsToWait: 60
        )
        guard let imageURL = output.images?.first?.url else {
            print("Fal response did not include an image URL")
            return
        }
        print("Your Flux Kontext Pro image is available at \(imageURL)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create Flux Kontext Pro image: \(error)")
    }
```

#### How to generate an image using Flux 2

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let falService = AIProxy.falDirectService(
    //     unprotectedAPIKey: "your-fal-key"
    // )

    /* Uncomment for all other production use cases */
    // let falService = AIProxy.falService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let input = FalFlux2InputSchema(
        prompt: "Yosemite Valley",
        enableSafetyChecker: false
    )
    do {
        let output = try await falService.createFlux2Image(
            input: input,
            secondsToWait: 120
        )
        print("""
              The first output image is at \(output.images?.first?.url?.absoluteString ?? "")
              It took \(output.timings?.inference ?? Double.nan) seconds to generate.
              """)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create Fal Flux 2 image: \(error)")
    }
```


***


## Groq

### How to generate a non-streaming chat completion using Groq

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let groqService = AIProxy.groqDirectService(
    //     unprotectedAPIKey: "your-groq-key"
    // )

    /* Uncomment for all other production use cases */
    // let groqService = AIProxy.groqService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let response = try await groqService.chatCompletionRequest(body: .init(
            messages: [.assistant(content: "hello world")],
            model: "mixtral-8x7b-32768"
        ))
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print(error)
    }
```


### How to generate a streaming chat completion using Groq

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let groqService = AIProxy.groqDirectService(
    //     unprotectedAPIKey: "your-groq-key"
    // )

    /* Uncomment for all other production use cases */
    // let groqService = AIProxy.groqService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let stream = try await groqService.streamingChatCompletionRequest(body: .init(
                messages: [.assistant(content: "hello world")],
                model: "mixtral-8x7b-32768"
            )
        )
        for try await chunk in stream {
            print(chunk.choices.first?.delta.content ?? "")
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print(error)
    }
```


### How to transcribe audio with Groq

1. Record an audio file in quicktime and save it as "helloworld.m4a"
2. Add the audio file to your Xcode project. Make sure it's included in your target: select your audio file in the project tree, type `cmd-opt-0` to open the inspect panel, and view `Target Membership`
3. Run this snippet:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let groqService = AIProxy.groqDirectService(
    //     unprotectedAPIKey: "your-groq-key"
    // )

    /* Uncomment for all other production use cases */
    // let groqService = AIProxy.groqService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let url = Bundle.main.url(forResource: "helloworld", withExtension: "m4a")!
        let requestBody = GroqTranscriptionRequestBody(
            file: try Data(contentsOf: url),
            model: "whisper-large-v3-turbo",
            responseFormat: "json"
        )
        let response = try await groqService.createTranscriptionRequest(body: requestBody)
        let transcript = response.text ?? "None"
        print("Groq transcribed: \(transcript)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not get audio transcription from Groq: \(error)")
    }
```


***

## Perplexity

### How to create a chat completion with Perplexity

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let perplexityService = AIProxy.perplexityDirectService(
    //     unprotectedAPIKey: "your-perplexity-key"
    // )

    /* Uncomment for all other production use cases */
    // let perplexityService = AIProxy.perplexityService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let response = try await perplexityService.chatCompletionRequest(body: .init(
            messages: [.user(content: "How many national parks in the US?")],
            model: "llama-3.1-sonar-small-128k-online"
        ))

        print(
            """
            Received from Perplexity:
            \(response.choices.first?.message?.content ?? "no content")

            With citations:
            \(response.citations ?? ["none"])

            Using:
            \(response.usage?.promptTokens ?? 0) prompt tokens
            \(response.usage?.completionTokens ?? 0) completion tokens
            \(response.usage?.totalTokens ?? 0) total tokens
            """
        )
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create perplexity chat completion: \(error)")
    }
```

### How to create a streaming chat completion with Perplexity

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let perplexityService = AIProxy.perplexityDirectService(
    //     unprotectedAPIKey: "your-perplexity-key"
    // )

    /* Uncomment for all other production use cases */
    // let perplexityService = AIProxy.perplexityService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let stream = try await perplexityService.streamingChatCompletionRequest(body: .init(
            messages: [.user(content: "How many national parks in the US?")],
            model: "llama-3.1-sonar-small-128k-online"
        ))

        var lastChunk: PerplexityChatCompletionResponseBody?
        for try await chunk in stream {
            print(chunk.choices.first?.delta?.content ?? "")
            lastChunk = chunk
        }

        if let lastChunk = lastChunk {
            print(
                """
                Citations:
                \(lastChunk.citations ?? ["none"])

                Using:
                \(lastChunk.usage?.promptTokens ?? 0) prompt tokens
                \(lastChunk.usage?.completionTokens ?? 0) completion tokens
                \(lastChunk.usage?.totalTokens ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create perplexity streaming chat completion: \(error)")
    }
```

***

## Mistral

### How to create a chat completion with Mistral

Use `api.mistral.ai` as the proxy domain when creating your AIProxy service in the developer dashboard.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let mistralService = AIProxy.mistralDirectService(
    //     unprotectedAPIKey: "your-mistral-key"
    // )

    /* Uncomment for all other production use cases */
    // let mistralService = AIProxy.mistralService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = MistralChatCompletionRequestBody(
        messages: [.user(content: "Hello world")],
        model: "mistral-small-latest"
    )
    do {
        let response = try await mistralService.chatCompletionRequest(
            body: requestBody,
            secondsToWait: 60
        )
        print(response.choices.first?.message.content ?? "")
        if let usage = response.usage {
            print(
                """
                Used:
                 \(usage.promptTokens ?? 0) prompt tokens
                 \(usage.completionTokens ?? 0) completion tokens
                 \(usage.totalTokens ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create mistral chat completion: \(error)")
    }
```


### How to create a streaming chat completion with Mistral

Use `api.mistral.ai` as the proxy domain when creating your AIProxy service in the developer dashboard.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let mistralService = AIProxy.mistralDirectService(
    //     unprotectedAPIKey: "your-mistral-key"
    // )

    /* Uncomment for all other production use cases */
    // let mistralService = AIProxy.mistralService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = MistralChatCompletionRequestBody(
        messages: [.user(content: "Hello world")],
        model: "mistral-small-latest"
    )
    do {
        let stream = try await mistralService.streamingChatCompletionRequest(
            body: requestBody,
            secondsToWait: 60
        )
        for try await chunk in stream {
            print(chunk.choices.first?.delta.content ?? "")
            if let usage = chunk.usage {
                print(
                    """
                    Used:
                     \(usage.promptTokens ?? 0) prompt tokens
                     \(usage.completionTokens ?? 0) completion tokens
                     \(usage.totalTokens ?? 0) total tokens
                    """
                )
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create mistral streaming chat completion: \(error)")
    }
```

### How to perform OCR with Mistral

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let mistralService = AIProxy.mistralDirectService(
    //     unprotectedAPIKey: "your-mistral-key"
    // )

    /* Uncomment for all other production use cases */
    // let mistralService = AIProxy.mistralService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    guard let image = NSImage(named: "hello_world") else {
        print("Could not find an image named 'hello_world' in your app assets")
        return
    }

    guard let imageURL = AIProxy.encodeImageAsURL(image: image, compressionQuality: 0.4) else {
        print("Could not convert image to data URL")
        return
    }

    let requestBody = MistralOCRRequestBody(
        document: .imageURLChunk(imageURL),
        model: .mistralOCRLatest,
        includeImageBase64: true
    )

    do {
        let response = try await mistralService.ocrRequest(
            body: requestBody,
            secondsToWait: 60
        )
        print(response.pages.first?.markdown ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not perform OCR request with Mistral: \(error)")
    }
```

### How to transcribe audio with Mistral (buffered case)

1. Record an audio file in quicktime and save it as "helloworld.m4a"
2. Add the audio file to your Xcode project. Make sure it's included in your target: select your audio file in the project tree, type `cmd-opt-0` to open the inspect panel, and view `Target Membership`
3. Run this snippet:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let mistralService = AIProxy.mistralDirectService(
    //     unprotectedAPIKey: "your-mistral-key"
    // )

    /* Uncomment for all other production use cases */
    // let mistralService = AIProxy.mistralService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let url = Bundle.main.url(forResource: "helloworld", withExtension: "m4a")!
        let requestBody = MistralTranscriptionRequestBody(
            model: "voxtral-mini-latest",
            file: try Data(contentsOf: url)
        )
        let response = try await mistralService.createTranscriptionRequest(
            body: requestBody,
            secondsToWait: 60
        )
        let transcript = response.text ?? "None"
        print("Mistral transcribed: \(transcript)")
        if let language = response.language {
            print("Language: \(language)")
        }
        if let usage = response.usage {
            print(
                """
                Used:
                 \(usage.promptTokens ?? 0) prompt tokens
                 \(usage.completionTokens ?? 0) completion tokens
                 \(usage.totalTokens ?? 0) total tokens
                 \(usage.promptAudioSeconds.map(String.init) ?? "n/a") prompt audio seconds
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create mistral transcription: \(error)")
    }
```

### How to transcribe audio with Mistral (streaming case)

1. Record an audio file in quicktime and save it as "helloworld.m4a"
2. Add the audio file to your Xcode project. Make sure it's included in your target: select your audio file in the project tree, type `cmd-opt-0` to open the inspect panel, and view `Target Membership`
3. Run this snippet:

```
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let mistralService = AIProxy.mistralDirectService(
    //     unprotectedAPIKey: "your-mistral-key"
    // )

    /* Uncomment for all other production use cases */
    // let mistralService = AIProxy.mistralService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let url = Bundle.main.url(forResource: "helloworld", withExtension: "m4a")!
        let requestBody = MistralTranscriptionRequestBody(
            model: "voxtral-mini-latest",
            file: try Data(contentsOf: url),
            timestampGranularities: [.segment]
        )
        let stream = try await mistralService.streamingTranscriptionRequest(
            body: requestBody,
            secondsToWait: 60
        )
        var assembled = ""
        for try await event in stream {
            switch event {
            case .textDelta(let delta):
                let text = delta.text ?? ""
                assembled += text
                print(text, terminator: "")
            case .language(let language):
                print("\nLanguage: \(language.audioLanguage ?? "unknown")")
            case .segment(let segment):
                print(
                    "\nSegment [\(segment.start.map { String($0) } ?? "?")-\(segment.end.map { String($0) } ?? "?")]: \(segment.text ?? "")"
                )
            case .done(let done):
                print("Done: \(done.text ?? assembled)")
                if let usage = done.usage {
                    print(
                        """
                        Used:
                         \(usage.promptTokens ?? 0) prompt tokens
                         \(usage.completionTokens ?? 0) completion tokens
                         \(usage.totalTokens ?? 0) total tokens
                         \(usage.promptAudioSeconds.map(String.init) ?? "n/a") prompt audio seconds
                        """
                    )
                }
            case .futureProof:
                print("Received new streaming event from mistral that we don't understand")
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not create mistral streaming transcription: \(error)")
    }
```

***

## EachAI

### How to kick off an EachAI workflow

Use `flows.eachlabs.ai` as the proxy domain when creating your AIProxy service in the developer dashboard.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let eachAIService = AIProxy.eachAIDirectService(
    //     unprotectedAPIKey: "your-eachAI-key"
    // )

    /* Uncomment for all other production use cases */
    // let eachAIService = AIProxy.eachAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    // Update the arguments here based on your eachlabs use case:
    let workflowID = "your-workflow-id"
    let requestBody = EachAITriggerWorkflowRequestBody(
        parameters: [
            "img": "https://storage.googleapis.com/magicpoint/models/women.png"
        ]
    )

    do {
        let triggerResponse = try await eachAIService.triggerWorkflow(
            workflowID: workflowID,
            body: requestBody
        )
        let executionResponse = try await eachAIService.pollForWorkflowExecutionComplete(
            workflowID: workflowID,
            triggerID: triggerResponse.triggerID
        )
        print("Workflow result is available at \(executionResponse.output ?? "output missing")")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not execute EachAI workflow: \(error)")
    }
```

### How to call Imagen on EachAI

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let eachAIService = AIProxy.eachAIDirectService(
    //     unprotectedAPIKey: "your-eachAI-key"
    // )

    /* Uncomment for all other production use cases */
    // let eachAIService = AIProxy.eachAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let input: EachAIImagenInput = EachAIImagenInput(prompt: "a skier")

    do {
        let url = try await eachAIService.createImagen4FastImage(
            input: input,
            pollAttempts: 60,
            secondsBetweenPollAttempts: 2
        )
        print("Your imagen output is available at: \(url)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not run Imagen 4 on EachAI: \(error)")
    }
```

### How to call Google Veo 3 Fast (Image to Video) on EachAI

The snippet below costs a few dollars per run on EachAI.
We recommend first running the Imagen example above, which is cheap.
This way you ensure that your EachAI + AIProxy integration is working correctly before kicking off many Veo runs.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let eachAIService = AIProxy.eachAIDirectService(
    //     unprotectedAPIKey: "your-eachAI-key"
    // )

    /* Uncomment for all other production use cases */
    // let eachAIService = AIProxy.eachAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

     // This model on EachAI does not currently accept a data URL. So you have to host the image somewhere first.
    let imageURL = URL(string: "https://storage.googleapis.com/magicpoint/inputs/veo3-fast-i2v-input.jpeg")!
    let input = EachAIVeoInput(
        imageURL: imageURL,
        prompt: """
            Cinematic video set in a bioluminescent underwater cave system on
            an alien ocean world, illuminated by glowing turquoise and violet
            corals. The scene opens with a smooth tracking shot through a
            tunnel of shimmering water, revealing a vast cavern where a swarm
            of robotic fish, each engraved with the 'eachlabs.ai' logo, swims
            in synchronized patterns. The camera follows the swarm as they
            weave through towering coral structures, their metallic bodies
            reflecting the cave’s radiant glow. A faint, rhythmic pulse of
            light emanates from the corals, creating a hypnotic effect.
            Suddenly, a massive, bioluminescent jellyfish-like creature drifts
            into view, its tentacles gently pulsating as it emits a low,
            resonant hum.  The audio includes the soft gurgle of water, a
            futuristic ambient soundtrack with ethereal tones, and the
            jellyfish’s hum synced with its movements. The video ends with a
            slow zoom-out, showing the swarm of robotic fish forming the shape
            of the 'eachlabs.ai' logo against the glowing cave backdrop,
            followed by a gentle fade to black. The style is photorealistic,
            with realistic fluid dynamics, vibrant lighting, and an immersive,
            otherworldly aesthetic.
            """
    )
    do {
        let url = try await eachAIService.createVeo3FastVideo(
            input: input,
            pollAttempts: 60,
            secondsBetweenPollAttempts: 10
        )
        print("Your veo3 output is available at: \(url)")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not run Veo3 on EachAI: \(error)")
    }
```

***

## OpenRouter


### How to make a streaming DeepSeek R1 completion with OpenRouter


```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openRouterService = AIProxy.openRouterDirectService(
    //     unprotectedAPIKey: "your-openRouter-key"
    // )

    /* Uncomment for all other production use cases */
    // let openRouterService = AIProxy.openRouterService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenRouterChatCompletionRequestBody(
        messages: [
            .system(content: .text("You are a math assistant.")),
            .user(content: .text("Here's why burgers' equation leads to a breaking nonlinearity in shallow water"))
        ],
        models: [
            "deepseek/deepseek-r1",
        ],
        reasoning: .init(effort: .low),
        temperature: 0.0 /* Set this based on your use case: https://api-docs.deepseek.com/quick_start/parameter_settings*/
    )

    do {
        let stream = try await openRouterService.streamingChatCompletionRequest(
            body: requestBody
        )
        for try await chunk in stream {
            if let reasoningContent = chunk.choices.first?.delta.reasoning {
                print("Reasoning chunk: \(reasoningContent)")
            }
            if let messageContent = chunk.choices.first?.delta.content {
                print("Message chunk: \(messageContent)")
            }
            if let usage = chunk.usage {
                print(
                    """
                    Served by \(chunk.provider ?? "unspecified")
                    using model \(chunk.model ?? "unspecified")
                    Used:
                     \(usage.promptTokens ?? 0) prompt tokens
                     \(usage.completionTokens ?? 0) completion tokens
                     \(usage.totalTokens ?? 0) total tokens
                    """
                )
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch let err as URLError where err.code == URLError.timedOut {
        print("Request for OpenRouter buffered chat completion timed out")
    } catch let err as URLError where [.notConnectedToInternet, .networkConnectionLost].contains(err.code) {
        print("Could not make OpenRouter streaming R1 chat request. Please check your internet connection")
    } catch {
        print("Could not get OpenRouter streaming R1 chat completion: \(error)")
    }
```

You may optionally add your provider preferences as part of the request body:

```swift
OpenRouterChatCompletionRequestBody(
  // ...
  provider: .init(order[
      "first-choice",
      "second-choice"
  ]),
  // ...
```

See the provider list here for the viable options: https://openrouter.ai/deepseek/deepseek-r1/providers
And then use the corresponding enum from this list: https://openrouter.ai/docs/features/provider-routing#json-schema-for-provider-preferences


### How to make a buffered DeepSeek R1 completion with OpenRouter

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openRouterService = AIProxy.openRouterDirectService(
    //     unprotectedAPIKey: "your-openRouter-key"
    // )

    /* Uncomment for all other production use cases */
    // let openRouterService = AIProxy.openRouterService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenRouterChatCompletionRequestBody(
        messages: [
            .system(content: .text("You are a math assistant.")),
            .user(content: .text("Here's why burgers' equation leads to a breaking nonlinearity in shallow water"))
        ],
        models: [
            "deepseek/deepseek-r1",
        ],
        reasoning: .init(effort: .low),
        temperature: 0.0 /* Set this based on your use case: https://api-docs.deepseek.com/quick_start/parameter_settings*/
    )

    do {

        let response = try await openRouterService.chatCompletionRequest(
            body: requestBody,
            secondsToWait: 300
        )

        print("""
            Served by \(response.provider ?? "unspecified")
            using model \(response.model ?? "unspecified")

            DeepSeek used the following reasoning:

            \(response.choices.first?.message.reasoning ?? "")

            And responded with:

            \(response.choices.first?.message.content ?? "")

            Used:
             \(response.usage?.completionTokens ?? 0) completion tokens
             \(response.usage?.promptTokens ?? 0) prompt tokens
             \(response.usage?.totalTokens ?? 0) total tokens
            """
        )
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch let err as URLError where err.code == URLError.timedOut {
        print("Request for OpenRouter buffered chat completion timed out")
    } catch let err as URLError where [.notConnectedToInternet, .networkConnectionLost].contains(err.code) {
        print("Could not make OpenRouter buffered R1 chat request. Please check your internet connection")
    } catch {
        print("Could not get OpenRouter buffered R1 chat completion: \(error)")
    }
```


You may optionally add your provider preferences as part of the request body:

```swift
OpenRouterChatCompletionRequestBody(
  // ...
  provider: .init(order[
      "first-choice",
      "second-choice"
  ]),
  // ...
```

See the provider list here for the viable options: https://openrouter.ai/deepseek/deepseek-r1/providers
And then use the corresponding enum from this list: https://openrouter.ai/docs/features/provider-routing#json-schema-for-provider-preferences


### How to make a non-streaming chat completion with OpenRouter

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openRouterService = AIProxy.openRouterDirectService(
    //     unprotectedAPIKey: "your-openRouter-key"
    // )

    /* Uncomment for all other production use cases */
    // let openRouterService = AIProxy.openRouterService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let requestBody = OpenRouterChatCompletionRequestBody(
            messages: [.user(content: .text("hello world"))],
            models: [
                "deepseek/deepseek-chat",
                "google/gemini-2.0-flash-exp:free",
                // ...
            ],
            route: .fallback
        )
        let response = try await openRouterService.chatCompletionRequest(requestBody)
        print("""
            Received: \(response.choices.first?.message.content ?? "")
            Served by \(response.provider ?? "unspecified")
            using model \(response.model ?? "unspecified")
            """
        )
        if let usage = response.usage {
            print(
                """
                Used:
                 \(usage.promptTokens ?? 0) prompt tokens
                 \(usage.completionTokens ?? 0) completion tokens
                 \(usage.totalTokens ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not get OpenRouter buffered chat completion: \(error)")
    }
```


### How to make a streaming chat completion with OpenRouter

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openRouterService = AIProxy.openRouterDirectService(
    //     unprotectedAPIKey: "your-openRouter-key"
    // )

    /* Uncomment for all other production use cases */
    // let openRouterService = AIProxy.openRouterService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenRouterChatCompletionRequestBody(
        messages: [.user(content: .text("hello world"))],
        models: [
            "deepseek/deepseek-chat",
            "google/gemini-2.0-flash-exp:free",
            // ...
        ],
        route: .fallback
    )

    do {
        let stream = try await openRouterService.streamingChatCompletionRequest(body: requestBody)
        for try await chunk in stream {
            print(chunk.choices.first?.delta.content ?? "")
            if let usage = chunk.usage {
                print(
                    """
                    Served by \(chunk.provider ?? "unspecified")
                    using model \(chunk.model ?? "unspecified")
                    Used:
                     \(usage.promptTokens ?? 0) prompt tokens
                     \(usage.completionTokens ?? 0) completion tokens
                     \(usage.totalTokens ?? 0) total tokens
                    """
                )
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not get OpenRouter streaming chat completion: \(error)")
    }
```


### How to make a streaming tool call with OpenRouter

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openRouterService = AIProxy.openRouterDirectService(
    //     unprotectedAPIKey: "your-openRouter-key"
    // )

    /* Uncomment for all other production use cases */
    // let openRouterService = AIProxy.openRouterService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenRouterChatCompletionRequestBody(
        messages: [
            .user(
                content: .text("What is the weather in SF?")
            )
        ],
        models: [
            "openai/gpt-4.1",
            // Add additional models here
        ],
        route: .fallback,
        tools: [
            .function(
                name: "get_weather",
                description: "Get current temperature for a given location.",
                parameters: [
                    "type": "object",
                    "properties": [
                        "location": [
                            "type": "string",
                            "description": "City and country e.g. Bogotá, Colombia"
                        ]
                    ],
                    "required": ["location"],
                    "additionalProperties": false
                ],
                strict: true
            )
        ]
    )
    do {
        let stream = try await openRouterService.streamingChatCompletionRequest(body: requestBody)
        for try await chunk in stream {
            guard let toolCall = chunk.choices.first?.delta.toolCalls?.first else {
                continue
            }
            if let name = toolCall.function?.name {
                print("Model wants to call the function \(name) with arguments:")
            }
            print(toolCall.function?.arguments ?? "")
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not get OpenRouter streaming tool call: \(error)")
    }
}

```


### How to make a structured outputs chat completion with OpenRouter

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openRouterService = AIProxy.openRouterDirectService(
    //     unprotectedAPIKey: "your-openRouter-key"
    // )

    /* Uncomment for all other production use cases */
    // let openRouterService = AIProxy.openRouterService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let schema: [String: AIProxyJSONValue] = [
            "type": "object",
            "properties": [
                "colors": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": [
                                "type": "string",
                                "description": "A descriptive name to give the color"
                            ],
                            "hex_code": [
                                "type": "string",
                                "description": "The hex code of the color"
                            ]
                        ],
                        "required": ["name", "hex_code"],
                        "additionalProperties": false
                    ]
                ]
            ],
            "required": ["colors"],
            "additionalProperties": false
        ]
        let requestBody = OpenRouterChatCompletionRequestBody(
            messages: [
                .system(content: .text("Return valid JSON only, and follow the specified JSON structure")),
                .user(content: .text("Return a peaches and cream color palette"))
            ],
            models: [
                "cohere/command-r7b-12-2024",
                "meta-llama/llama-3.3-70b-instruct",
                // ...
            ],
            responseFormat: .jsonSchema(
                name: "palette_creator",
                description: "A list of colors that make up a color pallete",
                schema: schema,
                strict: true
            ),
            route: .fallback
        )
        let response = try await openRouterService.chatCompletionRequest(body: requestBody)
        print("""
            Received: \(response.choices.first?.message.content ?? "")
            Served by \(response.provider ?? "unspecified")
            using model \(response.model ?? "unspecified")
            """
        )
        if let usage = response.usage {
            print(
                """
                Used:
                 \(usage.promptTokens ?? 0) prompt tokens
                 \(usage.completionTokens ?? 0) completion tokens
                 \(usage.totalTokens ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not get structured outputs response from OpenRouter: \(error)")
    }
```


### How to use vision requests on OpenRouter (multi-modal chat)
On macOS, use `NSImage(named:)` in place of `UIImage(named:)`

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openRouterService = AIProxy.openRouterDirectService(
    //     unprotectedAPIKey: "your-openRouter-key"
    // )

    /* Uncomment for all other production use cases */
    // let openRouterService = AIProxy.openRouterService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )
    guard let image = NSImage(named: "myImage") else {
        print("Could not find an image named 'myImage' in your app assets")
        return
    }

    guard let imageURL = AIProxy.encodeImageAsURL(image: image, compressionQuality: 0.6) else {
        print("Could not encode image as a data URL")
        return
    }

    do {
        let response = try await openRouterService.chatCompletionRequest(body: .init(
            messages: [
                .system(
                    content: .text("Tell me what you see")
                ),
                .user(
                    content: .parts(
                        [
                            .text("What do you see?"),
                            .imageURL(imageURL)
                        ]
                    )
                )
            ],
            models: [
                "x-ai/grok-2-vision-1212",
                "openai/gpt-4o"
            ],
            route: .fallback
        ))
        print("""
            Received: \(response.choices.first?.message.content ?? "")
            Served by \(response.provider ?? "unspecified")
            using model \(response.model ?? "unspecified")
            """
        )
        if let usage = response.usage {
            print(
                """
                Used:
                 \(usage.promptTokens ?? 0) prompt tokens
                 \(usage.completionTokens ?? 0) completion tokens
                 \(usage.totalTokens ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not make a vision request to OpenRouter: \(error)")
    }
```


### How to make a tool call with OpenRouter
```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openRouterService = AIProxy.openRouterDirectService(
    //     unprotectedAPIKey: "your-openRouter-key"
    // )

    /* Uncomment for all other production use cases */
    // let openRouterService = AIProxy.openRouterService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let completion = try await openRouterService.chatCompletionRequest(body: .init(
            messages: [
                .user(
                   content: .text("What is the weather in SF?")
               )
            ],
            models: [
                "cohere/command-r7b-12-2024",
                "meta-llama/llama-3.3-70b-instruct",
                // ...
            ],
            route: .fallback,
            tools: [
                .function(
                    name: "get_weather",
                    description: "Get current temperature for a given location.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "location": [
                                "type": "string",
                                "description": "City and country e.g. Bogotá, Colombia"
                            ]
                        ],
                        "required": ["location"],
                        "additionalProperties": false
                    ],
                    strict: true
                )
            ]
        ))
        if let toolCall = completion.choices.first?.message.toolCalls?.first {
            print("""
                The model wants us to call function: \(toolCall.function?.name ?? "")
                With arguments: \(toolCall.function?.arguments ?? [:])
                Served by \(completion.provider ?? "unspecified")
                using model \(completion.model ?? "unspecified")
                """
            )
        }
        if let usage = completion.usage {
            print(
                """
                Used:
                 \(usage.promptTokens ?? 0) prompt tokens
                 \(usage.completionTokens ?? 0) completion tokens
                 \(usage.totalTokens ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not get first chat completion: \(error)")
    }
```

***

## DeepSeek

### How to make a chat completion request with DeepSeek


```swift
    import AIProxySwift

    /* Uncomment for BYOK use cases */
    // let deepSeekService = AIProxy.deepSeekDirectService(
    //     unprotectedAPIKey: "your-deepseek-key"
    // )

    /* Uncomment for all other production use cases */
    // let deepSeekService = AIProxy.deepSeekService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = DeepSeekChatCompletionRequestBody(
        messages: [
            .system(content: "You are a helpful assistant."),
            .user(content: "Hello!")
        ],
        model: "deepseek-chat"
    )

    do {
        let response = try await deepSeekService.chatCompletionRequest(body: requestBody)
        print("\(response.choices.first?.message.content ?? "")")
        if let usage = response.usage {
            print(
                """
                Used:
                 \(usage.completionTokens ?? 0) completion tokens
                 \(usage.completionTokensDetails?.reasoningTokens ?? 0) reasoning tokens
                 \(usage.promptCacheHitTokens ?? 0) prompt cache hit tokens
                 \(usage.promptCacheMissTokens ?? 0) prompt cache miss tokens
                 \(usage.promptTokens ?? 0) prompt tokens
                 \(usage.totalTokens ?? 0) total tokens
                """
            )
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not get DeepSeek buffered chat completion: \(error)")
    }
```

### How to make a reasoning chat completion with DeepSeek R1

```swift
    import AIProxySwift

    /* Uncomment for BYOK use cases */
    // let deepSeekService = AIProxy.deepSeekDirectService(
    //     unprotectedAPIKey: "your-deepseek-key"
    // )

    /* Uncomment for all other production use cases */
    // let deepSeekService = AIProxy.deepSeekService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let requestBody = DeepSeekChatCompletionRequestBody(
            messages: [
                .system(content: "You are a math assistant. Don't use LaTeX, use utf-8 symbols only."),
                .user(content: "Here's why Burgers' equation leads to a breaking nonlinearity in shallow water")
            ],
            model: "deepseek-reasoner",
            temperature: 0.0 /* Set this based on your use case: https://api-docs.deepseek.com/quick_start/parameter_settings*/
        )
        let response = try await deepSeekService.chatCompletionRequest(
            body: requestBody,
            secondsToWait: 300
        )

        print(
            """
            DeepSeek used the following reasoning:

            \(response.choices.first?.message.reasoningContent ?? "")

            And responded with:

            \(response.choices.first?.message.content ?? "")

            Used:
             \(response.usage?.completionTokens ?? 0) completion tokens
             \(response.usage?.completionTokensDetails?.reasoningTokens ?? 0) reasoning tokens
             \(response.usage?.promptCacheHitTokens ?? 0) prompt cache hit tokens
             \(response.usage?.promptCacheMissTokens ?? 0) prompt cache miss tokens
             \(response.usage?.promptTokens ?? 0) prompt tokens
             \(response.usage?.totalTokens ?? 0) total tokens
            """
        )
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch let err as URLError where err.code == URLError.timedOut {
        print("Request for DeepSeek buffered chat completion timed out")
    } catch let err as URLError where [.notConnectedToInternet, .networkConnectionLost].contains(err.code) {
        print("Could not make buffered chat request. Please check your internet connection")
    } catch {
        print("Could not get DeepSeek buffered chat completion: \(error)")
    }
```

### How to make a streaming chat completion with DeepSeek

```swift
    import AIProxySwift

    /* Uncomment for BYOK use cases */
    // let deepSeekService = AIProxy.deepSeekDirectService(
    //     unprotectedAPIKey: "your-deepseek-key"
    // )

    /* Uncomment for all other production use cases */
    // let deepSeekService = AIProxy.deepSeekService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = DeepSeekChatCompletionRequestBody(
        messages: [
            .system(content: "You are a helpful assistant."),
            .user(content: "Hello!")
        ],
        model: "deepseek-chat"
    )

    do {
        let stream = try await deepSeekService.streamingChatCompletionRequest(body: requestBody)
        for try await chunk in stream {
            print(chunk.choices.first?.delta.content ?? "")
            if let usage = chunk.usage {
                print(
                    """
                    Used:
                    \(usage.completionTokens ?? 0) completion tokens
                    \(usage.completionTokensDetails?.reasoningTokens ?? 0) reasoning tokens
                    \(usage.promptCacheHitTokens ?? 0) prompt cache hit tokens
                    \(usage.promptCacheMissTokens ?? 0) prompt cache miss tokens
                    \(usage.promptTokens ?? 0) prompt tokens
                    \(usage.totalTokens ?? 0) total tokens
                    """
                )
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not make streaming DeepSeek request")
    }
```

### How to make a streaming reasoning chat completion with DeepSeek R1

```swift
    import AIProxySwift

    /* Uncomment for BYOK use cases */
    // let deepSeekService = AIProxy.deepSeekDirectService(
    //     unprotectedAPIKey: "your-deepseek-key"
    // )

    /* Uncomment for all other production use cases */
    // let deepSeekService = AIProxy.deepSeekService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = DeepSeekChatCompletionRequestBody(
        messages: [
            .system(content: "You are a math assistant. Don't use LaTeX, use utf-8 symbols only."),
            .user(content: "Here's why Burgers' equation leads to a breaking nonlinearity in shallow water")
        ],
        model: "deepseek-reasoner",
        temperature: 0.0 /* Set this based on your use case: https://api-docs.deepseek.com/quick_start/parameter_settings*/
    )

    do {
        let stream = try await deepSeekService.streamingChatCompletionRequest(body: requestBody)

        for try await chunk in stream {
            if let reasoningContent = chunk.choices.first?.delta.reasoningContent {
                print("Reasoning chunk: \(reasoningContent)")
            }
            if let messageContent = chunk.choices.first?.delta.content {
                print("Message chunk: \(messageContent)")
            }
            if let usage = chunk.usage {
                print(
                    """
                    Used:
                    \(usage.completionTokens ?? 0) completion tokens
                    \(usage.completionTokensDetails?.reasoningTokens ?? 0) reasoning tokens
                    \(usage.promptCacheHitTokens ?? 0) prompt cache hit tokens
                    \(usage.promptCacheMissTokens ?? 0) prompt cache miss tokens
                    \(usage.promptTokens ?? 0) prompt tokens
                    \(usage.totalTokens ?? 0) total tokens
                    """
                )
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch let err as URLError where err.code == URLError.timedOut {
        print("Request for DeepSeek R1 streaming chat completion timed out")
    } catch let err as URLError where [.notConnectedToInternet, .networkConnectionLost].contains(err.code) {
        print("Could not make DeepSeek R1 streaming chat request. Please check your internet connection")
    } catch {
        print("Could not get DeepSeek R1 streaming chat completion: \(error)")
    }
```

***


## Fireworks AI

### How to make a streaming DeepSeek R1 request to Fireworks AI

FireworksAI works differently than going to DeepSeek directly in that the reasoning content is
not on the messages's `reasoningContent` property. Instead, the reasoning content is included in
`message.content` enclosed in `<think></think>` tags:

```swift
    import AIProxySwift

    /* Uncomment for BYOK use cases */
    // let fireworksAIService = AIProxy.fireworksAIDirectService(
    //     unprotectedAPIKey: "your-fireworks-key"
    // )

    /* Uncomment for all other production use cases */
    // let fireworksAIService = AIProxy.fireworksAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = DeepSeekChatCompletionRequestBody(
        messages: [
            .system(content: "You are a math assistant."),
            .user(content: "Here's why burgers' equation leads to a breaking nonlinearity in shallow water")
        ],
        model: "accounts/fireworks/models/deepseek-r1",
        temperature: 0.0 /* Set this based on your use case: https://api-docs.deepseek.com/quick_start/parameter_settings*/
    )

    do {
        let stream = try await fireworksAIService.streamingDeepSeekR1Request(
            body: requestBody,
            secondsToWait: 300
        )
        for try await chunk in stream {
            print(chunk.choices.first?.delta.content ?? "")
            if let usage = chunk.usage {
                print(
                    """
                    Used:
                    \(usage.completionTokens ?? 0) completion tokens
                    \(usage.promptTokens ?? 0) prompt tokens
                    \(usage.totalTokens ?? 0) total tokens
                    """
                )
            }
        }
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch let err as URLError where err.code == URLError.timedOut {
        print("R1 request to FireworksAI timed out")
    } catch let err as URLError where [.notConnectedToInternet, .networkConnectionLost].contains(err.code) {
        print("Could not complete R1 request to FireworksAI. Please check your internet connection")
    } catch {
        print("Could not complete R1 request to FireworksAI: \(error)")
    }
```

### How to make a buffered DeepSeek R1 request to Fireworks AI
FireworksAI works differently than going to DeepSeek directly in that the reasoning content is
not on the messages's `reasoningContent` property. Instead, the reasoning content is included in
`message.content` enclosed in `<think></think>` tags:

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let fireworksAIService = AIProxy.fireworksAIDirectService(
    //     unprotectedAPIKey: "your-fireworks-key"
    // )

    /* Uncomment for all other production use cases */
    // let fireworksAIService = AIProxy.fireworksAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = DeepSeekChatCompletionRequestBody(
        messages: [
            .system(content: "You are a math assistant"),
            .user(content: "Here's why Burgers' equation leads to a breaking nonlinearity in shallow water")
        ],
        model: "accounts/fireworks/models/deepseek-r1",
        temperature: 0.0 /* Set this based on your use case: https://api-docs.deepseek.com/quick_start/parameter_settings*/
    )
    do {
        let response = try await fireworksAIService.deepSeekR1Request(
            body: requestBody,
            secondsToWait: 300
        )
        print(
            """
            FireworksAI puts the DeepSeek reasoning steps inside a <think></think> tags. Here's the full response:

            \(response.choices.first?.message.content ?? "")

            Used:
             \(response.usage?.completionTokens ?? 0) completion tokens
             \(response.usage?.promptTokens ?? 0) prompt tokens
             \(response.usage?.totalTokens ?? 0) total tokens
            """
        )
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch let err as URLError where err.code == URLError.timedOut {
        print("R1 request to FireworksAI timed out")
    } catch let err as URLError where [.notConnectedToInternet, .networkConnectionLost].contains(err.code) {
        print("Could not complete R1 request to FireworksAI. Please check your internet connection")
    } catch {
        print("Could not complete R1 request to FireworksAI: \(error)")
    }
```

***

## Brave

When you create a service in the AIProxy dashboard, use `https://api.search.brave.com` as the
proxy base URL.

```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let braveService = AIProxy.braveDirectService(
    //     unprotectedAPIKey: "your-brave-key"
    // )

    /* Uncomment for all other production use cases */
    // let braveService = AIProxy.braveService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    do {
        let searchResult = try await braveService.webSearchRequest(query: "How does concurrency work in Swift 6")
        let resultCount = searchResult.web?.results?.count ?? 0
        let urls = searchResult.web?.results?.compactMap { $0.url }
        print(
            """
            Brave responded with \(resultCount) search results.
            The search returned these urls: \(urls ?? [])
            """
        )
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Receivedt non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        // You may want to catch additional Foundation errors and pop the appropriate UI
        // to the user. See "How to catch Foundation errors for specific conditions" here:
        // https://www.aiproxy.com/docs/integration-options.html
        print("Could not make brave search: \(error)")
    }
```

***


## OpenMeteo

### How to fetch the weather with OpenMeteo

This pattern is slightly different than the others, because OpenMeteo has an official lib that
we'd like to rely on. To run the snippet below, you'll need to add AIProxySwift and
OpenMeteoSDK to your Xcode project. Add OpenMeteoSDK:

- In Xcode, go to `File > Add Package Dependences`
- Enter the package URL `https://github.com/open-meteo/sdk`
- Choose your dependency rule (e.g. the `main` branch for the most up-to-date package)

Next, use AIProxySwift's core functionality to get a URLRequest and URLSession, and pass those
into the OpenMeteoSDK:

```swift
    import AIProxy
    import OpenMeteoSdk

    do {
        let request = try await AIProxy.request(
            partialKey: "partial-key-from-your-aiproxy-developer-dashboard",
            serviceURL: "service-url-from-your-aiproxy-developer-dashboard",
            proxyPath: "/v1/forecast?latitude=52.52&longitude=13.41&hourly=temperature_2m&format=flatbuffers"
        )
        let session = AIProxy.session()
        let responses = try await WeatherApiResponse.fetch(request: request, session: session)
        // Do something with `responses`. For a usage example, follow these instructions:
        // 1. Navigate to https://open-meteo.com/en/docs
        // 2. Scroll to the 'API response' section
        // 3. Tap on Swift
        // 4. Scroll to 'Usage'
        print(responses)
    } catch {
        print("Could not fetch the weather: \(error)")
    }
```

***

## gRPC

### How to protect an existing gRPC call with AIProxy

AIProxySwift does not need to know about your protobuf messages or depend on your gRPC library.

Use your existing `HTTP2ClientTransport.TransportService` as usual, but set the host to your
AIProxy `serviceURL` and attach the required AIProxy metadata, demonstrated in the snippet below.

This example uses [grpc-swift](https://github.com/grpc/grpc-swift). Replace the generated
`Aiproxy_Tester_V1_*` types with the types generated from your own `.proto` file:

```swift
    import Foundation
    import AIProxy
    import GRPCCore
    import GRPCNIOTransportHTTP2

    let serviceURL = "service-url-from-your-developer-dashboard"

    do {
        guard let proxyURL = URL(string: serviceURL), let host = proxyURL.host else {
            print("Invalid AIProxy service URL")
            return
        }

        let proxyMetadata = try await AIProxy.grpcMetadata(
            partialKey: "partial-key-from-your-developer-dashboard",
            serviceURL: serviceURL
        )
        let metadata = Metadata(
            proxyMetadata.map { name, value in
                (name, .string(value))
            }
        )
        let transport = try HTTP2ClientTransport.TransportServices(
            target: .dns(host: host, port: proxyURL.port ?? 443),
            transportSecurity: .tls
        )

        let message = try await withGRPCClient(transport: transport) { client in
            let hello = Aiproxy_Tester_V1_HelloWorld.Client(wrapping: client)
            let request = Aiproxy_Tester_V1_HelloRequest.with { $0.name = "hello world" }
            let response = try await hello.sayHello(request, metadata: metadata)
            return response.message
        }
        print(message)
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch {
        print("Could not complete gRPC request: \(error)")
    }
```

***


## Advanced Settings

### Specify your own `clientID` to annotate requests

If your app already has client or user IDs that you want to annotate AIProxy requests with,
pass a second argument to the provider's service initializer. For example:

```swift
    let openAIService = AIProxy.openAIService(
        partialKey: "partial-key-from-your-developer-dashboard",
        serviceURL: "service-url-from-your-developer-dashboard",
        clientID: "<your-id>"
    )
```

Requests that are made using `openAIService` will be annotated on the AIProxy backend, so that
when you view top users, or the timeline of requests, your client IDs will be familiar.

If you do not have existing client or user IDs, no problem! Leave the `clientID` argument
out, and we'll generate IDs for you. See `AIProxyIdentifier.swift` if you would like to see
ID generation specifics.

### How to respond to DeviceCheck errors

Apple's DeviceCheck is a core component of our security model.

If your app can't generate a DeviceCheck token from the device, then it is unable to make a request to AIProxy's backend.
In such a case, you can pop UI to the end user by catching AIProxyError.deviceCheckIsUnavailble:

```swift
    let requestBody = OpenAIChatCompletionRequestBody(
        model: "gpt-4.1-mini-2025-04-14",
        messages: [
            .system(content: .text("You are a helpful assistant")),
            .user(content: .text("hello world"))
        ]
    )

    do {
        let response = try await openAIService.chatCompletionRequest(
            body: requestBody,
            secondsToWait: 60
        )
    } catch let error as AIProxyError where error == .deviceCheckIsUnavailable {
        // Pop UI to the end user here. Here is a sample message:
        //
        //     We could not create a required credential to make your AI request.
        //     Please make sure you are connected to the internet and your system clock is accurately set.
        //
    } catch {
        print("Could not create an OpenAI chat completion: \(error)")
    }
```


### How to catch Foundation errors for specific conditions

We use Foundation's `URL` types such as `URLRequest` and `URLSession` for all connections to
AIProxy. You can view the various errors that Foundation may raise by viewing NSURLError.h
(which is easiest to find by punching `cmd-shift-o` in Xcode and searching for it).

Some errors may be more interesting to you, and worth their own error handler to pop UI for
your user. For example, to catch `NSURLErrorTimedOut`, `NSURLErrorNetworkConnectionLost` and
`NSURLErrorNotConnectedToInternet`, you could use the following try/catch structure:

```swift
    import AIProxy

    let openAIService = AIProxy.openAIService(
        partialKey: "partial-key-from-your-developer-dashboard",
        serviceURL: "service-url-from-your-developer-dashboard"
    )

    do {
        let response = try await openAIService.chatCompletionRequest(body: .init(
            model: "gpt-4o-mini",
            messages: [.assistant(content: .text("hello world"))]
        ))
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received non-200 status code: \(statusCode) with response body: \(responseBody)")
    } catch let err as URLError where err.code == URLError.timedOut {
        print("Request for OpenAI buffered chat completion timed out")
    } catch let err as URLError where [.notConnectedToInternet, .networkConnectionLost].contains(err.code) {
        print("Could not make buffered chat request. Please check your internet connection")
    } catch {
        print("Could not get buffered chat completion: \(error)")
    }
```


# Troubleshooting


## No such module 'AIProxy' error
Occassionally, Xcode fails to automatically add the AIProxy library to your target's dependency
list.  If you receive the `No such module 'AIProxy'` error, first ensure that you have added
the package to Xcode using the [Installation steps](https://github.com/lzell/AIProxySwift?tab=readme-ov-file#installation).
Next, select your project in the Project Navigator (`cmd-1`), select your target, and scroll to
the `Frameworks, Libraries, and Embedded Content` section. Tap on the plus icon:

<img src="https://github.com/lzell/AIProxySwift/assets/35940/438e2bbb-688c-49bc-aa2a-ea85806818d5" alt="Add library dependency" width="820">

And add the AIProxy library:

<img src="https://github.com/lzell/AIProxySwift/assets/35940/f015a181-9591-435c-a37f-6fb0c8c5050c" alt="Select the AIProxy dependency" width="400">


## macOS network sandbox

If you encounter the error

    networkd_settings_read_from_file Sandbox is preventing this process from reading networkd settings file at "/Library/Preferences/com.apple.networkd.plist", please add an exception.

or

     A server with the specified hostname could not be found

or

     NSErrorFailingURLStringKey=https://api.aiproxy.com/your/service/url


Modify your macOS project settings by tapping on your project in the Xcode project tree, then
select `Signing & Capabilities` and enable `Outgoing Connections (client)`


## 'async' call in a function that does not support concurrency

If you use the snippets above and encounter the error

    'async' call in a function that does not support concurrency

it is because we assume you are in a structured concurrency context. If you encounter this
error, you can use the escape hatch of wrapping your snippet in a `Task {}`.


## Requests to AIProxy fail in iOS XCTest UI test cases

If you'd like to do UI testing and allow the test cases to execute real API requests, you must
set the `AIPROXY_DEVICE_CHECK_BYPASS` env variable in your test plan **and** forward the env
variable from the test case to the host simulator (Apple does not do this by default, which I
consider a bug). Here is how to set it up:

* Set the `AIPROXY_DEVICE_CHECK_BYPASS` env variable in your test environment:
  - Open the scheme editor at `Product > Scheme > Edit Scheme`
  - Select `Test`
  - Tap through to the test plan

    <img src="https://github.com/lzell/AIProxySwift/assets/35940/9a372244-f03e-4fe3-9361-ffc9d729b7d9" alt="Select test plan" width="720">

  - Select `Configurations > Environment Variables`

    <img src="https://github.com/lzell/AIProxySwift/assets/35940/2e042957-2c40-4335-833d-70b2bf56c31a" alt="Select env variables" width="780">

  - Add the `AIPROXY_DEVICE_CHECK_BYPASS` env variable with your value

    <img src="https://github.com/lzell/AIProxySwift/assets/35940/e466097c-1700-401d-add6-07c14dd26ab8" alt="Enter env variable value" width="720">

* **Important** Edit your test cases to forward on the env variable to the host simulator:

```swift
func testExample() throws {
    let app = XCUIApplication()
    app.launchEnvironment = [
        "AIPROXY_DEVICE_CHECK_BYPASS": ProcessInfo.processInfo.environment["AIPROXY_DEVICE_CHECK_BYPASS"]!
    ]
    app.launch()
}
```


# FAQ


## What is the `AIPROXY_DEVICE_CHECK_BYPASS` constant?

AIProxy uses Apple's [DeviceCheck](https://developer.apple.com/documentation/devicecheck) to ensure
that requests received by the backend originated from your app on a legitimate Apple device.
However, the iOS simulator cannot produce DeviceCheck tokens. Rather than requiring you to
constantly build and run on device during development, AIProxy provides a way to skip the
DeviceCheck integrity check. The token is intended for use by developers only. If an attacker gets
the token, they can make requests to your AIProxy project without including a DeviceCheck token, and
thus remove one level of protection.

The `AIPROXY_DEVICE_CHECK_BYPASS` is intended for the simulator only. Do not let it leak into
a distribution build of your app (including a TestFlight distribution). If you follow the
[integration steps](https://www.aiproxy.com/docs/integration-guide.html) we provide, then the
constant won't leak because env variables are not packaged into the app bundle.

## What is the `aiproxyPartialKey` constant?

This constant is intended to be **included** in the distributed version of your app. As the name implies, it is a
partial representation of your OpenAI key. Specifically, it is one half of an encrypted version of your key.
The other half resides on AIProxy's backend. As your app makes requests to AIProxy, the two encrypted parts
are paired, decrypted, and used to fulfill the request to OpenAI.


## Community contributions

Contributions are welcome! This library uses the MIT license.


## Contribution style guidelines

- Services should conform to a NameService protocol that defines the interface that the direct
  service and proxied service adopt. Factory methods on AIProxy.swift are typed to return an
  existential (e.g. NameService) rather than a concrete type (e.g. NameProxiedService)
  - Why do we do this? Two reason:
      1. We want to make it as easy as possible for lib users to swap between the BYOK use case
         and the proxied use case. By returning an existential, callers can use conditional
         logic in their app to select which service to use:

            ```
            let service = byok ? AIProxy.openaiDirectService() : AIProxy.openaiService()
            ```
      2. We prevent the direct and proxied concrete types from diverging in the public
         interface. As we add more functionality to the service's protocol, the compiler helps
         us ensure that the functionality is implemented for our two major use cases.

- In codable representations, fields that are required by the API should be above fields that
  are optional. Within the two groups (required and optional) all fields should be
  in the provider's documentation order. This makes it easier for contributors and LLMs
  to spot differences between the provider documentation and our encodable/decodable fields.
  Separate the two groups with a mark to aid users of ctrl-6:

  ```swift
  // MARK: Optional properties
  ```

- Decodables should all have optional properties. Why? We don't want to fail decoding in live
  apps if the provider changes something out from under us (which can happen purposefully due
  to deprecations, or by accident due to regressions). If we use non-optionals in decodable
  definitions, then a provider removing a field, changing the type of a field, or removing an
  enum case would cause decoding to fail. You may think this isn't too bad, since the
  JSONDecoder throws anyway, and therefore client code will already be wrapped in a do/catch.
  However, we always want to give the best chance that decodable succeeds _for the properties
  that the client actually uses_. That is, if the provider changes out the enum case of a
  property unused by the client, we want the client application to continue functioning
  correctly, not to throw an error and enter the catch branch of the client's call site.

- When a request or response object is deeply nested by the API provider, create nested types
  in the same namespace as the top level struct. For examples:

    ```swift
    public struct ProviderResponseBody: Decodable, Sendable {

        public let status: Status?

        // ... other fields ...
    }

    // MARK: -
    extension ProviderResponseBody {
        public enum Status: String, Decodable, Sendable {
            case succeeded
            case failed
            case canceled
        }
    }
    ```

  This pattern avoids collisions, works well with Xcode's cmd-click to jump to definition, and
  improves source understanding for folks that use `ctrl-6` to navigate through a file.

  You may wonder why we don't nest all types within the original top level type definition:

  ```swift
  public struct ProviderResponseBody: Decodable, Sendable {
      public enum Status: String, Decodable, Sendable {
          ...
      }
  }
  ```

  This approach is readable when the nested types are small and the nesting level is
  not too deep. When either of those conditions flip, readability suffers. This is particularly
  true for nested types that require their own coding keys and encodable/decodable logic, which
  balloon line count with implementation detail that a user of the top level type has no
  interest in.

  You may also wonder why we include the `// MARK: -` line. This is makes parsing the ctrl-6
  dropdown easier on the eyes.

- If you are implementing an API contract that could reuse a provider's nested structure, and
  it's reasonable to suppose that the two objects will change together, then pull the nested
  struct into its own file and give it a longer prefix. The example above would become:

    ```swift
    // ProviderResponseBody.swift
    public struct ProviderResponseBody: Decodable, Sendable {

        // An examples status
        public let status: ProviderStatus?

        // ... other fields ...
    }

    // ProviderStatus.swift
    public enum ProviderStatus: String, Decodable, Sendable {
        case succeeded
        case failed
        case canceled
    }
    ```

***

### Release naming guidelines

Give each release a semantic version *without* a `v` prefix on the version name. That is the
most reliable way to make Xcode's `File > Add Package Dependency` flow default to sane version
values.

***

### How to use AIProxySwift with custom services

If you'd like to proxy calls to a service that we don't have built-in support for, you can do
that with the following steps.

We recommend that you first go through the [standard integration video](https://www.aiproxy.com/docs/integration-guide.html)
for a built-in service. This way, any complications that you encounter with DeviceCheck will
be overcome before you embark on the custom integration. Once you are seeing 200s from a
built-in service, take the following steps to add a custom service to your app: 

1. Create an encodable representation of the request body. Let's say you are looking at a
   service's API docs and they specify an endpoint like this:

       POST api.example.com/chat

       Request body:

           - `great_prompt`: String

    You would define a request body that looks like this:

    ```swift
        struct ChatRequestBody: Encodable {
            let greatPrompt: String

            enum CodingKeys: String, CodingKey {
                case greatPrompt = "great_prompt"
            }
        }
    ```

2. Create a decodable represenation of the response body. Imagining an expanded API
   definition from above:

       POST api.example.com/chat

       Request body:

           - `great_prompt`: String

       Response body:

           - `generated_message`: String
   
    You would define a response body that looks like this:

    ```swift
        struct ChatResponseBody: Decodable, Sendable {
            let generatedMessage: String?

            enum CodingKeys: String, CodingKey {
                case generatedMessage = "generated_message"
            }
        }
    ```

    This example is straightforward. If the response body has a nested structure, which many
    do, you will need to add Decodables for the nested types. See the [Contribution style guidelines](#contribution-style-guidelines)
    above for an example of creating nested decodables.

    Pasting the API documentation into an LLM may get you a close representation of the nested
    structure that you can then polish.


3. Pay attention to the authorization header in your service's API docs. If it is of the form
   `Authorization: Bearer your-key` then it will work out of the box. If it is another form,
   please message me as I'll need to do a backend deploy (it's quick).

4. Create your service in the AIProxy dashboard entering in the base proxy URL for your
   service, e.g. in the example above it would be `api.example.com`

5. Submit your API key through the AIProxy dashboard for your service. You will get back a
   partial key and a service URL.

6. Use the information from preceeding steps to craft a request to AIProxy using the top level
   helper `AIProxy.request`. Continuing the example from above:

   ```swift
   import AIProxy

   func makeTestRequest() async throws {
       let requestBody = ChatRequestBody(
         greatPrompt: "hello world"
       )

       let request = try await AIProxy.request(
           partialKey: "partial-key-from-step-5",
           serviceURL: "service-url-from-step-5",
           proxyPath: "/chat",
           body: try JSONEncoder().encode(requestBody),
           verb: .post,
           headers: [
               "content-type": "application/json"
           ]
       )

       let session = AIProxy.session()
       let (data, res) = try await session.data(for: request)
       guard let httpResponse = res as? HTTPURLResponse else {
           print("Network response is not an http response")
           return
       }
       guard httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 else {
           print("Non-200 response")
           return
       }
       let chatResponseBody = try JSONDecoder().decode(
               ChatResponseBody.self,
              from: data
       )
       print(chatResponseBody.generatedMessage)
   }
   ```
    
6. Watch the Live Console in the AIProxy dashboard as you make test requests. It will tell you
   if a status code other than 200 is being returned.

At this point you should see successful responses in your Xcode project. If you are not, double
check your decodable definitions. If you are still not getting successful responses, message me
your encodables and decodables and I'll take a look as as soon as possible.

***

### Traffic sniffing with docker and mitmproxy (advanced)

The method above uses the documentation of a service to build the appropriate request and
response structures. There is another way, which takes longer to set up but has the advantage
of not relying on potentially stale documentation.

Most providers have an official node client. You can run the node client in a sample project
inside a docker container and point traffic at mitmproxy to inspect the contents of the
request/response structures. You can then take the request/response bodies and paste them into
an LLM to generate the encodable/decodable swift representations. Here's how:

1. Install mitmproxy and run it with `mitmproxy --listen-port 9090`

2. Create a Docker container using the client you are interested in. For example, to sniff traffic
from Gemini's official lib, I do this:

       mkdir ~/dev/node_docker_sandbox
       cd ~/dev/node_docker_sandbox
       cp ~/.mitmproxy/mitmproxy-ca-cert.pem .
       docker pull node:22
       vim Dockerfile

           FROM node:22
           WORKDIR /entrypoint
           COPY mitmproxy-ca-cert.pem /usr/local/share/ca-certificates/mitmproxy-ca-cert.pem
           ENV NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/mitmproxy-ca-cert.pem
           CMD ["node", "/entrypoint/generative-ai-js/samples/text_generation.js"]

       git clone https://github.com/google/generative-ai-js
       npm install --prefix generative-ai-js/samples
       docker --debug build -t node_docker_sandbox .

3. In Docker Desktop, go to Settings > Resources > Proxies and flip on 'Manual proxy
configuration'. Set both 'Web Server' and 'Secure Web Server' to `http://localhost:9090`

4. Run the docker container:

       docker run --volume "$(pwd)/:/entrypoint/" node_docker_sandbox

If all is set up correctly, you will see requests and responses flow through mitmproxy in plain
text. You can use those bodies to build your swift structs, implementing an encodable
representation for the request body and decodable representation for response body.
