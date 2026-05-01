-- Breeves v1 — initial schema
-- Tables: profiles, user_topics, daily_briefings (+ RLS)

-- profiles ────────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    notification_enabled boolean not null default true,
    notification_time time not null default '05:30:00'::time,
    default_lens text not null default 'universal'
        check (default_lens in ('universal', 'topic_specific', 'executive')),
    brief_length text not null default 'standard'
        check (brief_length in ('compact', 'standard', 'extended')),
    color_scheme text not null default 'system'
        check (color_scheme in ('system', 'dark', 'light')),
    tz text not null default 'UTC',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- user_topics ─────────────────────────────────────────────────────────────────
create table if not exists public.user_topics (
    user_id uuid not null references auth.users(id) on delete cascade,
    slot int not null check (slot between 1 and 3),
    topic text not null,
    description text,
    created_at timestamptz not null default now(),
    primary key (user_id, slot)
);

-- daily_briefings ─────────────────────────────────────────────────────────────
create table if not exists public.daily_briefings (
    user_id uuid not null references auth.users(id) on delete cascade,
    briefing_date date not null,
    payload jsonb not null,
    generated_at timestamptz not null default now(),
    primary key (user_id, briefing_date)
);

create index if not exists daily_briefings_date_idx
    on public.daily_briefings (briefing_date desc);

-- read_state (track per-article read state) ──────────────────────────────────
create table if not exists public.article_read_state (
    user_id uuid not null references auth.users(id) on delete cascade,
    briefing_date date not null,
    article_id text not null,
    read_at timestamptz not null default now(),
    primary key (user_id, briefing_date, article_id)
);

-- updated_at trigger ─────────────────────────────────────────────────────────
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
    before update on public.profiles
    for each row execute function public.touch_updated_at();

-- RLS ─────────────────────────────────────────────────────────────────────────
alter table public.profiles            enable row level security;
alter table public.user_topics         enable row level security;
alter table public.daily_briefings     enable row level security;
alter table public.article_read_state  enable row level security;

-- profiles: users see/update only their own row
drop policy if exists profiles_self on public.profiles;
create policy profiles_self on public.profiles
    for all using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists user_topics_self on public.user_topics;
create policy user_topics_self on public.user_topics
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists daily_briefings_self on public.daily_briefings;
create policy daily_briefings_self on public.daily_briefings
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists article_read_state_self on public.article_read_state;
create policy article_read_state_self on public.article_read_state
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- profile bootstrapping on signup ─────────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
    insert into public.profiles (id) values (new.id) on conflict do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();
