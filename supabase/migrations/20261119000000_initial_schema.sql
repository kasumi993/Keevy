-- ═══════════════════════════════════════════════════════════════════════════
-- KEEVY — initial schema
-- Boards (Inspiration / Projet) → sections → cards, contacts (prestataires)
-- linked to boards with a per-board status, checklists, share links,
-- collaborators, freemium limits, storage for card images.
--
-- Apply with:  supabase db push   (or paste in the SQL editor)
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Enums ───────────────────────────────────────────────────────────────────
create type public.board_mode    as enum ('inspiration', 'projet');
create type public.event_type    as enum ('mariage', 'baby_shower', 'anniversaire', 'cremaillere', 'evjf', 'demenagement', 'autre');
create type public.card_kind     as enum ('image', 'link', 'note');
create type public.vendor_status as enum ('decouvert', 'contacte', 'devis', 'confirme', 'ecarte');
create type public.share_access  as enum ('read', 'edit');

-- ── Generic helpers ─────────────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Safe text → uuid cast (returns null instead of raising), used by storage policies.
create or replace function public.try_uuid(p text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return p::uuid;
exception when others then
  return null;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLES
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Profiles (1:1 with auth.users) ─────────────────────────────────────────
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  email         text,
  display_name  text check (char_length(display_name) <= 80),
  avatar_url    text,
  locale        text not null default 'fr' check (locale in ('fr', 'en')),
  is_premium    boolean not null default false,
  premium_until timestamptz,
  onboarded_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ── Boards ──────────────────────────────────────────────────────────────────
create table public.boards (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 80),
  emoji       text check (char_length(emoji) <= 8),
  color       text not null default '#B07860' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  mode        public.board_mode not null default 'inspiration',
  event_type  public.event_type,
  target_date date,
  position    double precision not null default 0,
  archived_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index boards_owner_idx on public.boards (owner_id);

-- ── Collaborators (joined through an "edit" share link) ────────────────────
create table public.board_members (
  board_id   uuid not null references public.boards (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (board_id, user_id)
);
create index board_members_user_idx on public.board_members (user_id);

-- ── Sections (columns inside a board) ──────────────────────────────────────
create table public.sections (
  id         uuid primary key default gen_random_uuid(),
  board_id   uuid not null references public.boards (id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 60),
  position   double precision not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index sections_board_idx on public.sections (board_id);

-- ── Contacts / prestataires (one entity, found everywhere) ─────────────────
create table public.contacts (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  name            text not null check (char_length(name) between 1 and 120),
  profession      text check (char_length(profession) <= 80),
  phone           text,
  email           text,
  instagram       text,
  tiktok          text,
  website         text,
  recommended_by  text check (char_length(recommended_by) <= 120),
  notes           text check (char_length(notes) <= 5000),
  avatar_url      text,
  -- sha256 of the strongest normalised identifier (instagram > email > phone > website),
  -- computed client-side; prevents creating the same vendor twice.
  identifier_hash text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (owner_id, identifier_hash)
);
create index contacts_owner_idx on public.contacts (owner_id);

-- ── Board ↔ contact link, with the per-project vendor status ───────────────
create table public.board_contacts (
  board_id       uuid not null references public.boards (id) on delete cascade,
  contact_id     uuid not null references public.contacts (id) on delete cascade,
  status         public.vendor_status not null default 'decouvert',
  price_estimate numeric(12, 2) check (price_estimate >= 0),
  currency       text not null default 'EUR' check (char_length(currency) = 3),
  notes          text check (char_length(notes) <= 5000),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  primary key (board_id, contact_id)
);
create index board_contacts_contact_idx on public.board_contacts (contact_id);

-- ── Cards (image / link / note) ─────────────────────────────────────────────
create table public.cards (
  id           uuid primary key default gen_random_uuid(),
  board_id     uuid not null references public.boards (id) on delete cascade,
  section_id   uuid references public.sections (id) on delete set null,
  created_by   uuid default auth.uid() references public.profiles (id) on delete set null,
  kind         public.card_kind not null,
  title        text check (char_length(title) <= 300),
  body         text check (char_length(body) <= 10000),
  url          text check (char_length(url) <= 2048),
  -- Gallery uploads live in the private "card-images" bucket at <board_id>/<file>.
  image_path   text,
  -- Remote preview image (Open Graph). Social images are never copied: we keep the URL.
  image_url    text check (char_length(image_url) <= 2048),
  image_width  integer check (image_width > 0),
  image_height integer check (image_height > 0),
  source       text check (source in ('instagram', 'tiktok', 'pinterest', 'twitter', 'youtube', 'facebook', 'web', 'gallery', 'note')),
  domain       text,
  contact_id   uuid references public.contacts (id) on delete set null,
  position     double precision not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint cards_content_check check (
    (kind = 'image' and (image_path is not null or image_url is not null))
    or (kind = 'link' and url is not null)
    or (kind = 'note' and (coalesce(body, '') <> '' or coalesce(title, '') <> ''))
  )
);
create index cards_board_idx   on public.cards (board_id);
create index cards_section_idx on public.cards (section_id);
create index cards_contact_idx on public.cards (contact_id);
create index cards_kind_idx    on public.cards (kind, created_at desc);

-- ── Checklist tasks (Projet mode) ───────────────────────────────────────────
create table public.tasks (
  id           uuid primary key default gen_random_uuid(),
  board_id     uuid not null references public.boards (id) on delete cascade,
  parent_id    uuid references public.tasks (id) on delete cascade,
  contact_id   uuid references public.contacts (id) on delete set null,
  title        text not null check (char_length(title) between 1 and 300),
  done         boolean not null default false,
  due_date     date,
  position     double precision not null default 0,
  template_key text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index tasks_board_idx   on public.tasks (board_id);
create index tasks_parent_idx  on public.tasks (parent_id);
create index tasks_contact_idx on public.tasks (contact_id);

-- ── Share links ─────────────────────────────────────────────────────────────
create table public.board_shares (
  id         uuid primary key default gen_random_uuid(),
  board_id   uuid not null references public.boards (id) on delete cascade,
  token      text not null unique
             default replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
  access     public.share_access not null default 'read',
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);
create index board_shares_board_idx on public.board_shares (board_id);

-- ── updated_at triggers ─────────────────────────────────────────────────────
create trigger profiles_updated_at       before update on public.profiles       for each row execute function public.set_updated_at();
create trigger boards_updated_at         before update on public.boards         for each row execute function public.set_updated_at();
create trigger sections_updated_at       before update on public.sections       for each row execute function public.set_updated_at();
create trigger contacts_updated_at       before update on public.contacts       for each row execute function public.set_updated_at();
create trigger board_contacts_updated_at before update on public.board_contacts for each row execute function public.set_updated_at();
create trigger cards_updated_at          before update on public.cards          for each row execute function public.set_updated_at();
create trigger tasks_updated_at          before update on public.tasks          for each row execute function public.set_updated_at();

-- ── Data API privileges ─────────────────────────────────────────────────────
-- Explicit, so the app works even when "automatically expose new tables" is off.
-- Row access is still decided by RLS below; profiles is narrowed further down.
grant usage on schema public to anon, authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- ACCESS HELPERS (security definer → no RLS recursion)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.is_board_owner(p_board uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.boards b
    where b.id = p_board and b.owner_id = (select auth.uid())
  );
$$;

create or replace function public.can_access_board(p_board uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.boards b
    where b.id = p_board and b.owner_id = (select auth.uid())
  ) or exists (
    select 1 from public.board_members m
    where m.board_id = p_board and m.user_id = (select auth.uid())
  );
$$;

create or replace function public.is_premium(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.is_premium and (p.premium_until is null or p.premium_until > now())
    from public.profiles p where p.id = p_user
  ), false);
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTH HOOK: profile row for every new user
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, display_name, locale)
  values (
    new.id,
    new.email,
    nullif(coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'), ''),
    case when new.raw_user_meta_data ->> 'locale' = 'en' then 'en' else 'fr' end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ═══════════════════════════════════════════════════════════════════════════
-- FREEMIUM RULES (enforced server-side; the app shows the paywall on these codes)
--   free    : unlimited Inspiration boards, max 3 active Projet boards, read-only share links
--   premium : unlimited Projet boards, collaborative (edit) share links
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.enforce_projet_board_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if new.mode = 'projet'
     and new.archived_at is null
     and (tg_op = 'INSERT' or old.mode is distinct from 'projet' or old.archived_at is not null)
     and not public.is_premium(new.owner_id) then
    select count(*) into v_count
    from public.boards b
    where b.owner_id = new.owner_id
      and b.mode = 'projet'
      and b.archived_at is null
      and b.id <> new.id;
    if v_count >= 3 then
      raise exception 'KEEVY_LIMIT_PROJET_BOARDS' using errcode = 'P0001',
        hint = 'Free plan: max 3 Projet boards. Upgrade to Keevy Premium.';
    end if;
  end if;
  return new;
end;
$$;

create trigger boards_projet_limit
  before insert or update of mode, archived_at on public.boards
  for each row execute function public.enforce_projet_board_limit();

create or replace function public.enforce_edit_share_premium()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  if new.access = 'edit' then
    select b.owner_id into v_owner from public.boards b where b.id = new.board_id;
    if not public.is_premium(v_owner) then
      raise exception 'KEEVY_PREMIUM_REQUIRED_EDIT_SHARE' using errcode = 'P0001',
        hint = 'Collaborative share links require Keevy Premium.';
    end if;
  end if;
  return new;
end;
$$;

create trigger board_shares_edit_premium
  before insert or update of access on public.board_shares
  for each row execute function public.enforce_edit_share_premium();

-- A card can only point to a section of its own board.
create or replace function public.enforce_card_section_board()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.section_id is not null and not exists (
    select 1 from public.sections s where s.id = new.section_id and s.board_id = new.board_id
  ) then
    raise exception 'KEEVY_SECTION_BOARD_MISMATCH' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger cards_section_board
  before insert or update of section_id, board_id on public.cards
  for each row execute function public.enforce_card_section_board();

-- ═══════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.profiles       enable row level security;
alter table public.boards         enable row level security;
alter table public.board_members  enable row level security;
alter table public.sections       enable row level security;
alter table public.contacts       enable row level security;
alter table public.board_contacts enable row level security;
alter table public.cards          enable row level security;
alter table public.tasks          enable row level security;
alter table public.board_shares   enable row level security;

-- Profiles: own row only. Premium columns are not writable by clients.
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (display_name, avatar_url, locale, onboarded_at) on public.profiles to authenticated;

-- Boards: owner + collaborators can read; only the owner changes or deletes.
create policy boards_select on public.boards for select to authenticated
  using (public.can_access_board(id));
create policy boards_insert on public.boards for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy boards_update on public.boards for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy boards_delete on public.boards for delete to authenticated
  using (owner_id = (select auth.uid()));

-- Members: visible to the owner and to the member; the owner removes, a member can leave.
create policy board_members_select on public.board_members for select to authenticated
  using (user_id = (select auth.uid()) or public.is_board_owner(board_id));
create policy board_members_delete on public.board_members for delete to authenticated
  using (user_id = (select auth.uid()) or public.is_board_owner(board_id));
-- (inserts only through accept_board_share())

-- Sections / cards / tasks: anyone with access to the board.
create policy sections_select on public.sections for select to authenticated using (public.can_access_board(board_id));
create policy sections_insert on public.sections for insert to authenticated with check (public.can_access_board(board_id));
create policy sections_update on public.sections for update to authenticated using (public.can_access_board(board_id)) with check (public.can_access_board(board_id));
create policy sections_delete on public.sections for delete to authenticated using (public.can_access_board(board_id));

create policy cards_select on public.cards for select to authenticated using (public.can_access_board(board_id));
create policy cards_insert on public.cards for insert to authenticated with check (public.can_access_board(board_id));
create policy cards_update on public.cards for update to authenticated using (public.can_access_board(board_id)) with check (public.can_access_board(board_id));
create policy cards_delete on public.cards for delete to authenticated using (public.can_access_board(board_id));

create policy tasks_select on public.tasks for select to authenticated using (public.can_access_board(board_id));
create policy tasks_insert on public.tasks for insert to authenticated with check (public.can_access_board(board_id));
create policy tasks_update on public.tasks for update to authenticated using (public.can_access_board(board_id)) with check (public.can_access_board(board_id));
create policy tasks_delete on public.tasks for delete to authenticated using (public.can_access_board(board_id));

-- Contacts: owned by one user; collaborators can read the vendors linked to a shared board.
create policy contacts_select on public.contacts for select to authenticated
  using (
    owner_id = (select auth.uid())
    or exists (
      select 1 from public.board_contacts bc
      where bc.contact_id = contacts.id and public.can_access_board(bc.board_id)
    )
  );
create policy contacts_insert on public.contacts for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy contacts_update on public.contacts for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy contacts_delete on public.contacts for delete to authenticated
  using (owner_id = (select auth.uid()));

create policy board_contacts_select on public.board_contacts for select to authenticated
  using (public.can_access_board(board_id));
create policy board_contacts_insert on public.board_contacts for insert to authenticated
  with check (
    public.can_access_board(board_id)
    and exists (select 1 from public.contacts c where c.id = contact_id and c.owner_id = (select auth.uid()))
  );
create policy board_contacts_update on public.board_contacts for update to authenticated
  using (public.can_access_board(board_id)) with check (public.can_access_board(board_id));
create policy board_contacts_delete on public.board_contacts for delete to authenticated
  using (public.can_access_board(board_id));

-- Share links: managed by the board owner only (public reads go through get_shared_board()).
create policy board_shares_all on public.board_shares for all to authenticated
  using (public.is_board_owner(board_id)) with check (public.is_board_owner(board_id));

-- ═══════════════════════════════════════════════════════════════════════════
-- VIEWS
-- ═══════════════════════════════════════════════════════════════════════════

-- Home screen: boards with counters and up to 4 preview images (respects RLS).
create view public.board_overview with (security_invoker = true) as
select
  b.*,
  (b.owner_id = (select auth.uid())) as is_owner,
  (select count(*) from public.cards c where c.board_id = b.id)::int as card_count,
  (select count(*) from public.board_contacts bc where bc.board_id = b.id)::int as contact_count,
  (select count(*) from public.tasks t where t.board_id = b.id and t.parent_id is null)::int as task_count,
  (select count(*) from public.tasks t where t.board_id = b.id and t.parent_id is null and t.done)::int as task_done_count,
  coalesce((
    select jsonb_agg(jsonb_build_object('image_path', p.image_path, 'image_url', p.image_url))
    from (
      select c.image_path, c.image_url
      from public.cards c
      where c.board_id = b.id and (c.image_path is not null or c.image_url is not null)
      order by c.created_at desc
      limit 4
    ) p
  ), '[]'::jsonb) as previews
from public.boards b;

grant select on public.board_overview to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- RPCs
-- ═══════════════════════════════════════════════════════════════════════════

-- Public read-only snapshot of a shared board (used by the web viewer /s/<token>
-- through the shared-board Edge Function, which signs image URLs).
create or replace function public.get_shared_board(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_share public.board_shares;
  v_result jsonb;
begin
  select * into v_share from public.board_shares s
  where s.token = p_token and s.revoked_at is null;
  if not found then
    return null;
  end if;

  select jsonb_build_object(
    'access', v_share.access,
    'board', to_jsonb(b) - 'owner_id',
    'owner_name', coalesce(p.display_name, split_part(p.email, '@', 1)),
    'sections', coalesce((
      select jsonb_agg(to_jsonb(s) order by s.position, s.created_at)
      from public.sections s where s.board_id = b.id
    ), '[]'::jsonb),
    'cards', coalesce((
      select jsonb_agg(to_jsonb(c) - 'created_by' order by c.position, c.created_at)
      from public.cards c where c.board_id = b.id
    ), '[]'::jsonb)
  ) into v_result
  from public.boards b
  join public.profiles p on p.id = b.owner_id
  where b.id = v_share.board_id and b.archived_at is null;

  return v_result;
end;
$$;

-- Join a board as collaborator through an "edit" share link.
create or replace function public.accept_board_share(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_share public.board_shares;
  v_owner uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'KEEVY_AUTH_REQUIRED' using errcode = 'P0001';
  end if;

  select * into v_share from public.board_shares s
  where s.token = p_token and s.revoked_at is null;
  if not found then
    raise exception 'KEEVY_SHARE_NOT_FOUND' using errcode = 'P0001';
  end if;

  select b.owner_id into v_owner from public.boards b where b.id = v_share.board_id;
  if v_owner = (select auth.uid()) then
    return v_share.board_id;
  end if;

  if v_share.access <> 'edit' then
    raise exception 'KEEVY_SHARE_READ_ONLY' using errcode = 'P0001';
  end if;

  insert into public.board_members (board_id, user_id)
  values (v_share.board_id, (select auth.uid()))
  on conflict do nothing;

  return v_share.board_id;
end;
$$;

-- Atomic reorder helper: moves a card to a section and position.
create or replace function public.move_card(p_card uuid, p_section uuid, p_position double precision)
returns void
language sql
security invoker
set search_path = ''
as $$
  update public.cards
  set section_id = p_section, position = p_position
  where id = p_card;
$$;

revoke all on function public.get_shared_board(text)   from public;
revoke all on function public.accept_board_share(text) from public;
revoke all on function public.move_card(uuid, uuid, double precision) from public;
grant execute on function public.get_shared_board(text)   to anon, authenticated, service_role;
grant execute on function public.accept_board_share(text) to authenticated;
grant execute on function public.move_card(uuid, uuid, double precision) to authenticated;

-- Internal helpers are not meant to be called through the API.
revoke all on function public.handle_new_user()             from public, anon, authenticated;
revoke all on function public.enforce_projet_board_limit()  from public, anon, authenticated;
revoke all on function public.enforce_edit_share_premium()  from public, anon, authenticated;
revoke all on function public.is_premium(uuid)              from public, anon;
grant execute on function public.is_premium(uuid) to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- STORAGE — private bucket for gallery images: card-images/<board_id>/<file>
-- ═══════════════════════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('card-images', 'card-images', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/gif'])
on conflict (id) do nothing;

create policy card_images_select on storage.objects for select to authenticated
  using (bucket_id = 'card-images'
         and public.can_access_board(public.try_uuid((storage.foldername(name))[1])));
create policy card_images_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'card-images'
              and public.can_access_board(public.try_uuid((storage.foldername(name))[1])));
create policy card_images_update on storage.objects for update to authenticated
  using (bucket_id = 'card-images'
         and public.can_access_board(public.try_uuid((storage.foldername(name))[1])));
create policy card_images_delete on storage.objects for delete to authenticated
  using (bucket_id = 'card-images'
         and public.can_access_board(public.try_uuid((storage.foldername(name))[1])));
