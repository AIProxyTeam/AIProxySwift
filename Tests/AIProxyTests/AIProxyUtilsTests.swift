import Testing
@testable import AIProxy

@Suite("AIProxyUtils")
struct AIProxyUtilsTests {

    @Test("Project and service identifiers are parsed from a service URL")
    func serviceIdentifiers() throws {
        let identifiers = try AIProxyUtils.serviceIdentifiers(
            from: "https://api.aiproxy.com/eb34427b/f62cb466"
        )

        #expect(identifiers.project == "eb34427b")
        #expect(identifiers.service == "f62cb466")
    }

    @Test("Query parameters and fragments are ignored")
    func queryParametersAndFragments() throws {
        let identifiers = try AIProxyUtils.serviceIdentifiers(
            from: "https://api.aiproxy.com/project/service?environment=test#fragment"
        )

        #expect(identifiers.project == "project")
        #expect(identifiers.service == "service")
    }

    @Test(
        "Service URLs without exactly two path components are rejected",
        arguments: [
            "https://api.aiproxy.com",
            "https://api.aiproxy.com/project",
            "https://api.aiproxy.com/project/service/extra"
        ]
    )
    func invalidPathComponents(serviceURL: String) {
        #expect(throws: AIProxyError.self) {
            _ = try AIProxyUtils.serviceIdentifiers(from: serviceURL)
        }
    }

    @Test("Unparseable service URLs are rejected")
    func unparseableServiceURL() {
        #expect(throws: AIProxyError.self) {
            _ = try AIProxyUtils.serviceIdentifiers(
                from: "https://[invalid/project/service"
            )
        }
    }
}
