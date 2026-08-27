import Parsing

public struct SearchProof<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let candidate: SearchCandidate<ID>
    public let matches: [StructuredParser.Match]

    public init(
        candidate: SearchCandidate<ID>,
        matches: [StructuredParser.Match]
    ) {
        self.candidate = candidate
        self.matches = matches
    }

    public var documentID: ID {
        candidate.documentID
    }

    public var matchCount: Int {
        matches.count
    }
}

extension SearchProof: Codable where ID: Codable {}

public struct SearchProofResult<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let candidateCount: Int
    public let proofs: [SearchProof<ID>]

    public init(
        candidateCount: Int,
        proofs: [SearchProof<ID>]
    ) {
        self.candidateCount = candidateCount
        self.proofs = proofs
    }

    public var provenCandidateCount: Int {
        proofs.count
    }

    public var matchCount: Int {
        proofs.reduce(
            into: 0
        ) { count, proof in
            count += proof.matchCount
        }
    }

    public var isEmpty: Bool {
        proofs.isEmpty
    }
}

extension SearchProofResult: Codable where ID: Codable {}
