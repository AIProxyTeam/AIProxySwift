import Network
import Testing
@testable import AIProxy

struct OpenAIRealtimeTLSVersionTests {
    @Test func selectsTheMostSpecificApplicableDomain() {
        let domains: [String: Any] = [
            "example.test": ["NSExceptionMinimumTLSVersion": "TLSv1.3", "NSIncludesSubdomains": true],
            "local.example.test": ["NSExceptionMinimumTLSVersion": "TLSv1.2"],
            "exact.test": ["NSExceptionMinimumTLSVersion": "TLSv1.3"],
        ]
        for host in ["EXAMPLE.TEST", "x.example.test", "exact.test"] {
            #expect(OpenAIRealtimeTLS.minimumVersion(for: host, exceptionDomains: domains, systemMinimum: .TLSv12) == .TLSv13)
        }
        for host in ["local.example.test", "notexample.test", "exact.test.", "x.exact.test"] {
            #expect(OpenAIRealtimeTLS.minimumVersion(for: host, exceptionDomains: domains, systemMinimum: .TLSv12) == .TLSv12)
        }
    }

    @Test func usesTheMostSpecificNumericAddressRuleWithoutResolvingDNS() {
        let domains: [String: Any] = [
            "192.0.2.0/25": ["NSExceptionMinimumTLSVersion": "TLSv1.3"],
            "192.0.2.1": [:] as [String: Any],
            "2001:db8::/32": ["NSExceptionMinimumTLSVersion": "TLSv1.3"],
            "2001:db8:abcd::/48": [:] as [String: Any],
        ]
        for host in ["192.0.2.127", "[2001:db8:1234::1]"] {
            #expect(OpenAIRealtimeTLS.minimumVersion(for: host, exceptionDomains: domains, systemMinimum: .TLSv12) == .TLSv13)
        }
        for host in ["192.0.2.1", "192.0.2.128", "2001:db8:abcd::1", "example.test"] {
            #expect(OpenAIRealtimeTLS.minimumVersion(for: host, exceptionDomains: domains, systemMinimum: .TLSv12) == .TLSv12)
        }
    }

    @Test func aRuleCannotLowerTheSystemOrSDKMinimum() {
        let domains = ["example.test": ["NSExceptionMinimumTLSVersion": "TLSv1.0"]]
        #expect(OpenAIRealtimeTLS.minimumVersion(for: "example.test", exceptionDomains: domains, systemMinimum: .TLSv13) == .TLSv13)
        #expect(OpenAIRealtimeTLS.minimumVersion(for: "example.test", exceptionDomains: domains, systemMinimum: .TLSv12) == .TLSv12)
    }
}
