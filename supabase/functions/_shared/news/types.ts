// Shared types for the news-source dispatcher.

/// A raw news article candidate before summarization. Sources produce these,
/// dispatcher dedupes them, ranking + extraction populates `body`, and the
/// Claude summarizer turns them into Article objects matching
/// Packages/Models/Sources/Models/Article.swift.
export interface Candidate {
    /// Canonical URL after redirect resolution. Used for deduping.
    url: string;
    headline: string;
    /// Display name of the source ("Hacker News", "GDELT (Reuters)").
    source: string;
    /// ISO 8601, UTC. Sources that don't expose a published timestamp use
    /// fetch-time as a fallback.
    publishedAt: string;
    /// Full article text. Empty until extract.ts populates it.
    body?: string;
}

export interface NewsSource {
    name: string;
    /// Returns up to `limit` candidates relevant to `query`. Implementations
    /// are responsible for catching their own errors and returning [] on
    /// failure — never throw, never bring down the dispatcher.
    search(query: string, limit: number): Promise<Candidate[]>;
    /// True when the source is configured (env var present, feature flag on).
    /// Disabled sources return [] from search().
    enabled: boolean;
}
