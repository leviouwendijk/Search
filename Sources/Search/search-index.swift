import Parsing

/// A caller-owned, revision-aware in-memory index. Revisions are opaque:
/// Search never derives filesystem state or assumes anything about its source.
public struct SearchIndex<ID: Hashable & Sendable, Revision: Hashable & Sendable> {
    public struct Descriptor: Hashable, Sendable {
        public let id: ID
        public let revision: Revision

        public init(id: ID, revision: Revision) {
            self.id = id
            self.revision = revision
        }
    }

    public struct UpdatePlan: Sendable {
        public let requested: [Descriptor]
        public let reused: [Descriptor]
        public let requiresMaterialization: [Descriptor]
        public let added: [Descriptor]
        public let changed: [Descriptor]
        public let removed: [ID]

        fileprivate let baseline: [Descriptor]
    }

    public struct UpdateStatistics: Sendable, Equatable {
        public let indexedDocuments: Int
        public let reusedDocuments: Int
        public let addedDocuments: Int
        public let changedDocuments: Int
        public let removedDocuments: Int
        public let tokenizations: Int
        public let reusedTokenizations: Int
    }

    public enum IndexError: Swift.Error {
        case duplicateDescriptor(ID)
        case stalePlan
        case duplicateMaterialization(ID)
        case unexpectedMaterialization(ID)
        case missingMaterialization(ID)
    }

    private struct Entry {
        let document: SearchDocument<ID>
        let revision: Revision
        let tokens: [LexedToken]
    }

    private var entries: [ID: Entry] = [:]
    private var order: [ID] = []

    public init() {}

    public var count: Int {
        order.count
    }

    public var descriptors: [Descriptor] {
        order.compactMap { id in
            guard let entry = entries[id] else {
                return nil
            }
            return Descriptor(id: id, revision: entry.revision)
        }
    }

    public var corpus: SearchCorpus<ID> {
        SearchCorpus(
            documents: order.compactMap { entries[$0]?.document }
        )
    }

    /// Compare IDs and revisions only. No source content is requested here.
    /// A missing index entry always requires materialization, even when the
    /// caller's own source cache reports that source as unchanged.
    public func plan(current requested: [Descriptor]) throws -> UpdatePlan {
        var seen: Set<ID> = []
        var reused: [Descriptor] = []
        var needed: [Descriptor] = []
        var added: [Descriptor] = []
        var changed: [Descriptor] = []

        for descriptor in requested {
            guard seen.insert(descriptor.id).inserted else {
                throw IndexError.duplicateDescriptor(descriptor.id)
            }

            if let existing = entries[descriptor.id] {
                if existing.revision == descriptor.revision {
                    reused.append(descriptor)
                } else {
                    changed.append(descriptor)
                    needed.append(descriptor)
                }
            } else {
                added.append(descriptor)
                needed.append(descriptor)
            }
        }

        return UpdatePlan(
            requested: requested,
            reused: reused,
            requiresMaterialization: needed,
            added: added,
            changed: changed,
            removed: order.filter { !seen.contains($0) },
            baseline: descriptors
        )
    }

    /// Materialized documents must cover precisely the required IDs in the
    /// plan. Every retained entry keeps its old text and lexical token stream.
    /// A failed validation leaves the entire index untouched.
    @discardableResult
    public mutating func apply(
        _ plan: UpdatePlan,
        materialized documents: [SearchDocument<ID>]
    ) throws -> UpdateStatistics {
        guard descriptors == plan.baseline else {
            throw IndexError.stalePlan
        }

        let required = Set(plan.requiresMaterialization.map(\.id))
        var supplied: [ID: SearchDocument<ID>] = [:]

        for document in documents {
            guard required.contains(document.id) else {
                throw IndexError.unexpectedMaterialization(document.id)
            }
            guard supplied.updateValue(document, forKey: document.id) == nil else {
                throw IndexError.duplicateMaterialization(document.id)
            }
        }

        for descriptor in plan.requiresMaterialization {
            guard supplied[descriptor.id] != nil else {
                throw IndexError.missingMaterialization(descriptor.id)
            }
        }

        var next: [ID: Entry] = [:]
        next.reserveCapacity(plan.requested.count)

        for descriptor in plan.requested {
            if let existing = entries[descriptor.id],
               existing.revision == descriptor.revision {
                next[descriptor.id] = existing
                continue
            }

            guard let document = supplied[descriptor.id] else {
                throw IndexError.missingMaterialization(descriptor.id)
            }

            next[descriptor.id] = Entry(
                document: document,
                revision: descriptor.revision,
                tokens: LexicalSearch.tokenize(document.text)
            )
        }

        entries = next
        order = plan.requested.map(\.id)

        return UpdateStatistics(
            indexedDocuments: order.count,
            reusedDocuments: plan.reused.count,
            addedDocuments: plan.added.count,
            changedDocuments: plan.changed.count,
            removedDocuments: plan.removed.count,
            tokenizations: plan.requiresMaterialization.count,
            reusedTokenizations: plan.reused.count
        )
    }

    /// Runs the canonical LexicalSearch matcher over cached token streams.
    /// Does not tokenize indexed documents again on subsequent queries.
    public func search(
        _ pattern: LexicalPattern,
        caseSensitive: Bool = true
    ) -> LexicalSearchResult<ID> {
        var matches: [LexicalMatch<ID>] = []
        var matchedDocumentCount = 0

        for id in order {
            guard let entry = entries[id] else {
                continue
            }

            let documentMatches = LexicalSearch.indexedMatches(
                pattern,
                in: entry.document,
                tokens: entry.tokens,
                caseSensitive: caseSensitive
            )

            if !documentMatches.isEmpty {
                matchedDocumentCount += 1
                matches.append(contentsOf: documentMatches)
            }
        }

        return LexicalSearchResult(
            searchedDocumentCount: order.count,
            matchedDocumentCount: matchedDocumentCount,
            matches: matches
        )
    }
}
