-- Hứng quà 10 năm · Lotus Hospitality: bảng xếp hạng chung.
-- Same Supabase project as the Kahoot game (vngroup23.github.io) and the GPCN survey.
-- Apply with:  node ../../../Game/scripts/db.mjs apply supabase/schema.sql   (run from this folder)
--
-- NOTE: the Kahoot game's schema.sql revokes execute on every function in public. If it is
-- re-run, re-run this file afterwards to restore the grants at the bottom.
--
-- Rules (same idea as the Kahoot game): BTC press Start on #admin, every phone counts down to
-- catch.config.starts_at and the whole room plays the same `duration` seconds, ending together.
-- Each phone number gets catch.config.turns rounds (1). Players are ranked by score; ties go to
-- whoever's result reached the server first. BTC gives prizes to the Top 5.
--
-- BTC log in with the Kahoot admin key (public.app_config.admin_key_hash).

create extension if not exists pgcrypto with schema extensions;

create schema if not exists catch;
revoke all on schema catch from public, anon, authenticated;

create table if not exists catch.config (
  id int primary key default 1 check (id = 1),
  turns int not null default 1 check (turns between 1 and 50),
  duration int not null default 45,      -- seconds of play, the same for everyone
  starts_at timestamptz,                 -- set by BTC; null = waiting for BTC
  max_score int not null default 3000    -- far above what a real round reaches
);
insert into catch.config (id) values (1) on conflict do nothing;

create table if not exists catch.players (
  id uuid primary key default gen_random_uuid(),
  token uuid not null unique,
  name text not null,
  phone text not null unique,
  unit text not null,
  created_at timestamptz not null default now()
);

create table if not exists catch.plays (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references catch.players(id) on delete cascade,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  score int,
  logos int,
  cakes int,
  storms int
);
create index if not exists plays_player_idx on catch.plays (player_id);

revoke all on all tables in schema catch from public, anon, authenticated;

-- ---------- helpers (not callable from the browser) ----------
create or replace function catch.admin_ok(p_key text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select coalesce((
    select admin_key_hash is not null and admin_key_hash = crypt(coalesce(p_key, ''), admin_key_hash)
    from public.app_config where id = 1
  ), false);
$$;

create or replace function catch.require_admin(p_key text) returns void
language plpgsql security definer set search_path = catch as $$
begin
  if not catch.admin_ok(p_key) then raise exception 'FORBIDDEN'; end if;
end $$;

create or replace function catch.clean(p text, p_max int default 80) returns text
language sql immutable as $$
  select nullif(left(regexp_replace(btrim(coalesce(p, '')), '\s+', ' ', 'g'), p_max), '');
$$;

create or replace function catch.status() returns text
language sql stable security definer set search_path = catch as $$
  select case when starts_at is null then 'waiting'
              when now() < starts_at then 'countdown'
              when now() < starts_at + make_interval(secs => duration) then 'running'
              else 'ended' end
  from catch.config where id = 1;
$$;

create or replace function catch.state_json() returns json
language sql stable security definer set search_path = catch as $$
  select json_build_object(
    'status', catch.status(),
    'startsAt', (extract(epoch from starts_at) * 1000)::bigint,
    'serverNow', (extract(epoch from clock_timestamp()) * 1000)::bigint,
    'duration', duration,
    'players', (select count(*) from catch.players),
    'played', (select count(*) from catch.plays where finished_at is not null)
  ) from catch.config where id = 1;
$$;

-- Best finished round per player, ranked. Ties: earlier finish of that best round wins.
create or replace function catch.ranking() returns table (
  player_id uuid, name text, phone text, unit text, best int, best_at timestamptz,
  plays bigint, rank bigint
)
language sql stable security definer set search_path = catch as $$
  with best as (
    select distinct on (p.player_id) p.player_id, p.score, p.finished_at
    from catch.plays p
    where p.finished_at is not null
    order by p.player_id, p.score desc, p.finished_at asc
  ), counts as (
    select player_id, count(*) as n from catch.plays group by player_id
  )
  select pl.id, pl.name, pl.phone, pl.unit, b.score, b.finished_at, coalesce(c.n, 0),
         row_number() over (order by b.score desc, b.finished_at asc)
  from best b
  join catch.players pl on pl.id = b.player_id
  left join counts c on c.player_id = pl.id;
$$;

create or replace function catch.me_json(p_player uuid) returns json
language sql stable security definer set search_path = catch as $$
  select json_build_object(
    'name', pl.name, 'phone', pl.phone, 'unit', pl.unit,
    'turnsLeft', greatest(0, (select turns from catch.config where id = 1) - (select count(*) from catch.plays where player_id = pl.id)),
    'best', r.best, 'rank', r.rank,
    'players', (select count(*) from catch.ranking())
  )
  from catch.players pl
  left join catch.ranking() r on r.player_id = pl.id
  where pl.id = p_player;
$$;

revoke all on all functions in schema catch from public, anon, authenticated;

-- ---------- public API (called from the page with the publishable key) ----------

-- Register or log in by phone number. The phone is the identity; the token ties this browser to it.
create or replace function public.catch_register(p_token uuid, p_name text, p_phone text, p_unit text) returns json
language plpgsql security definer set search_path = catch as $$
declare v_name text := catch.clean(p_name, 60); v_unit text := catch.clean(p_unit, 60);
        v_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'); v_id uuid;
begin
  if p_token is null or v_name is null or v_unit is null or v_phone !~ '^0[35789][0-9]{8}$' then
    raise exception 'BAD_INPUT';
  end if;
  insert into catch.players (token, name, phone, unit) values (p_token, v_name, v_phone, v_unit)
  on conflict (phone) do update set token = excluded.token, name = excluded.name, unit = excluded.unit
  returning id into v_id;
  return catch.me_json(v_id);
end $$;

create or replace function public.catch_state() returns json
language sql stable security definer set search_path = catch as $$ select catch.state_json(); $$;

create or replace function public.catch_me(p_token uuid) returns json
language sql stable security definer set search_path = catch as $$
  select catch.me_json(id) from catch.players where token = p_token;
$$;

-- Uses up one turn and returns the round id that catch_finish must quote.
create or replace function public.catch_start(p_token uuid) returns json
language plpgsql security definer set search_path = catch as $$
declare v_player uuid; v_play uuid; cfg catch.config;
begin
  select * into cfg from catch.config where id = 1;
  -- only from shortly before the shared start until the shared end
  if cfg.starts_at is null or now() < cfg.starts_at - interval '20 seconds' then raise exception 'NOT_STARTED'; end if;
  if now() >= cfg.starts_at + make_interval(secs => cfg.duration) then raise exception 'ENDED'; end if;
  select id into v_player from catch.players where token = p_token for update;
  if v_player is null then raise exception 'NO_PLAYER'; end if;
  if (select count(*) from catch.plays where player_id = v_player) >= cfg.turns then raise exception 'NO_TURNS'; end if;
  insert into catch.plays (player_id) values (v_player) returning id into v_play;
  return json_build_object('play', v_play,
    'turnsLeft', cfg.turns - (select count(*) from catch.plays where player_id = v_player),
    'state', catch.state_json());
end $$;

create or replace function public.catch_finish(p_token uuid, p_play uuid, p_score int, p_logos int, p_cakes int, p_storms int) returns json
language plpgsql security definer set search_path = catch as $$
declare v_player uuid; v_started timestamptz; cfg catch.config;
begin
  select * into cfg from catch.config where id = 1;
  select id into v_player from catch.players where token = p_token;
  select started_at into v_started from catch.plays
    where id = p_play and player_id = v_player and finished_at is null for update;
  if v_started is null then raise exception 'BAD_INPUT'; end if;
  if p_score is null or p_score < 0 or p_score > cfg.max_score or p_score % 10 <> 0
     or coalesce(p_logos, -1) < 0 or p_score > p_logos * 60
     or now() < cfg.starts_at + make_interval(secs => cfg.duration - 5)
     or now() > cfg.starts_at + make_interval(secs => cfg.duration + 180) then
    raise exception 'REJECTED';
  end if;
  update catch.plays set finished_at = now(), score = p_score, logos = p_logos,
    cakes = greatest(0, coalesce(p_cakes, 0)), storms = greatest(0, coalesce(p_storms, 0))
  where id = p_play;
  return catch.me_json(v_player);
end $$;

-- Public leaderboard: everyone with a finished round. Phone numbers are masked.
create or replace function public.catch_board() returns json
language sql stable security definer set search_path = catch as $$
  select coalesce(json_agg(json_build_object(
    'rank', rank, 'name', name, 'unit', unit, 'best', best,
    'phone', left(phone, 3) || 'x xxx ' || right(phone, 3)
  ) order by rank), '[]'::json)
  from catch.ranking();
$$;

-- ---------- BTC ----------
create or replace function public.catch_admin_check(p_key text) returns boolean
language sql stable security definer set search_path = catch as $$ select catch.admin_ok(p_key); $$;

create or replace function public.catch_admin_board(p_key text) returns json
language plpgsql security definer set search_path = catch as $$
begin
  perform catch.require_admin(p_key);
  return json_build_object(
    'config', (select row_to_json(c) from catch.config c where id = 1),
    'state', catch.state_json(),
    'players', (select count(*) from catch.players),
    'rows', (select coalesce(json_agg(json_build_object(
      'id', player_id, 'rank', rank, 'name', name, 'phone', phone, 'unit', unit,
      'best', best, 'bestAt', best_at, 'plays', plays) order by rank), '[]'::json) from catch.ranking())
  );
end $$;

-- Start the shared round: every phone counts down to now() + p_delay seconds.
create or replace function public.catch_admin_start(p_key text, p_delay int default 10) returns json
language plpgsql security definer set search_path = catch as $$
begin
  perform catch.require_admin(p_key);
  if catch.status() <> 'waiting' then raise exception 'BAD_STATE'; end if;
  update catch.config set starts_at = now() + make_interval(secs => greatest(3, least(coalesce(p_delay, 10), 60))) where id = 1;
  return catch.state_json();
end $$;

-- New round: wipe every score (players stay registered) and wait for BTC again.
create or replace function public.catch_admin_reset(p_key text) returns json
language plpgsql security definer set search_path = catch as $$
begin
  perform catch.require_admin(p_key);
  delete from catch.plays where true;
  update catch.config set starts_at = null where id = 1;
  return catch.state_json();
end $$;

-- Remove a player (e.g. cheating). Their rounds go with them.
create or replace function public.catch_admin_delete(p_key text, p_player uuid) returns void
language plpgsql security definer set search_path = catch as $$
begin
  perform catch.require_admin(p_key);
  delete from catch.players where id = p_player;
end $$;

revoke all on function
  public.catch_register(uuid, text, text, text), public.catch_me(uuid), public.catch_start(uuid),
  public.catch_finish(uuid, uuid, int, int, int, int), public.catch_board(), public.catch_state(),
  public.catch_admin_check(text), public.catch_admin_board(text), public.catch_admin_start(text, int), public.catch_admin_reset(text),
  public.catch_admin_delete(text, uuid)
from public;

grant execute on function
  public.catch_register(uuid, text, text, text), public.catch_me(uuid), public.catch_start(uuid),
  public.catch_finish(uuid, uuid, int, int, int, int), public.catch_board(), public.catch_state(),
  public.catch_admin_check(text), public.catch_admin_board(text), public.catch_admin_start(text, int), public.catch_admin_reset(text),
  public.catch_admin_delete(text, uuid)
to anon, authenticated;
