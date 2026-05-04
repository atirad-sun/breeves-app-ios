-- Phase 0a — briefing_articles history table.
--
-- Append-only history of every article ever surfaced to a user. The
-- existing daily_briefings table continues to serve as the user's
-- "current view" for a given date (overwritten on refresh); this table
-- preserves every article that's ever been generated so the cross-day
-- dedup query (next-7-days lookback) is cheap and a future history
-- screen has data to read.
--
-- Identity is (user_id, canonical_url). When the same article would be
-- generated again, the upsert is a no-op — first_seen_date stays pinned
-- to the original day so dedup windows are honored.

create table if not exists public.briefing_articles (
    user_id uuid not null references auth.users(id) on delete cascade,
    canonical_url text not null,
    article_id text not null,
    headline text not null,
    source text not null,
    url text not null,
    topic text not null,
    published_at timestamptz,
    first_seen_date date not null,
    payload jsonb not null,
    created_at timestamptz not null default now(),
    primary key (user_id, canonical_url)
);

-- Cross-day dedup query: where user_id = ? and first_seen_date >= today - 7
create index if not exists briefing_articles_user_recent_idx
    on public.briefing_articles (user_id, first_seen_date desc);

-- RLS: users can only read their own history.
alter table public.briefing_articles enable row level security;

drop policy if exists briefing_articles_self on public.briefing_articles;
create policy briefing_articles_self on public.briefing_articles
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
