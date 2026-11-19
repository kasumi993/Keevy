-- ═══════════════════════════════════════════════════════════════════════════
-- Keevy — RLS & business-rule smoke test.
-- Run against a LOCAL database (supabase start) as the postgres user:
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/rls_smoke.sql
-- Everything runs in a transaction that is rolled back: no data is left behind.
-- ═══════════════════════════════════════════════════════════════════════════
begin;

-- Fixed ids so the script can switch identities.
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'alice@test.dev', '{"full_name":"Alice"}'),
  ('00000000-0000-0000-0000-00000000000b', 'bob@test.dev',   '{"full_name":"Bob","locale":"en"}'),
  ('00000000-0000-0000-0000-00000000000c', 'carol@test.dev', '{}');

do $$ begin
  assert (select count(*) from public.profiles) = 3, 'profiles must be auto-created';
  assert (select locale from public.profiles where email = 'bob@test.dev') = 'en', 'locale from metadata';
end $$;

-- ── Alice ───────────────────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);

insert into public.boards (id, name, mode) values
  ('10000000-0000-0000-0000-000000000001', 'Mariage', 'projet'),
  ('10000000-0000-0000-0000-000000000002', 'Baby shower', 'projet'),
  ('10000000-0000-0000-0000-000000000003', 'Crémaillère', 'projet'),
  ('10000000-0000-0000-0000-000000000004', 'Déco salon', 'inspiration');

-- 4th Projet board refused on the free plan (insert and switch).
do $$ begin
  insert into public.boards (name, mode) values ('Anniversaire', 'projet');
  raise exception 'TEST FAILED: projet limit on insert';
exception when others then
  if sqlerrm <> 'KEEVY_LIMIT_PROJET_BOARDS' then raise; end if;
end $$;
do $$ begin
  update public.boards set mode = 'projet' where id = '10000000-0000-0000-0000-000000000004';
  raise exception 'TEST FAILED: projet limit on update';
exception when others then
  if sqlerrm <> 'KEEVY_LIMIT_PROJET_BOARDS' then raise; end if;
end $$;

-- Archiving one frees a slot.
update public.boards set archived_at = now() where id = '10000000-0000-0000-0000-000000000003';
update public.boards set mode = 'projet' where id = '10000000-0000-0000-0000-000000000004';
-- …and un-archiving is refused while 3 are active.
do $$ begin
  update public.boards set archived_at = null where id = '10000000-0000-0000-0000-000000000003';
  raise exception 'TEST FAILED: projet limit on unarchive';
exception when others then
  if sqlerrm <> 'KEEVY_LIMIT_PROJET_BOARDS' then raise; end if;
end $$;

-- Clients cannot grant themselves premium.
do $$ begin
  update public.profiles set is_premium = true where id = '00000000-0000-0000-0000-00000000000a';
  raise exception 'TEST FAILED: is_premium must not be writable';
exception when insufficient_privilege then null;
end $$;
update public.profiles set display_name = 'Alice K.' where id = '00000000-0000-0000-0000-00000000000a';

-- Sections, cards, contacts.
insert into public.sections (id, board_id, name, position) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Robes', 0),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'Déco', 0);
insert into public.cards (board_id, section_id, kind, url, image_url, source) values
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'link',
   'https://www.instagram.com/p/abc', 'https://cdn.example.com/a.jpg', 'instagram');
insert into public.cards (board_id, kind, body, source) values
  ('10000000-0000-0000-0000-000000000001', 'note', 'Penser aux pivoines', 'note');

-- A card cannot use a section of another board.
do $$ begin
  insert into public.cards (board_id, section_id, kind, body)
  values ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', 'note', 'x');
  raise exception 'TEST FAILED: section/board mismatch';
exception when others then
  if sqlerrm <> 'KEEVY_SECTION_BOARD_MISMATCH' then raise; end if;
end $$;
-- Empty cards are rejected.
do $$ begin
  insert into public.cards (board_id, kind) values ('10000000-0000-0000-0000-000000000001', 'link');
  raise exception 'TEST FAILED: empty link card';
exception when check_violation then null;
end $$;

insert into public.contacts (id, name, profession, instagram, identifier_hash) values
  ('30000000-0000-0000-0000-000000000001', 'Atelier Rosa', 'Fleuriste', 'atelier.rosa', 'hash-rosa');
do $$ begin
  insert into public.contacts (name, identifier_hash) values ('Atelier Rosa bis', 'hash-rosa');
  raise exception 'TEST FAILED: duplicate contact';
exception when unique_violation then null;
end $$;
insert into public.board_contacts (board_id, contact_id, status, price_estimate)
values ('10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'devis', 850);
insert into public.tasks (board_id, title, contact_id) values
  ('10000000-0000-0000-0000-000000000001', 'Envoyer le moodboard', '30000000-0000-0000-0000-000000000001');

do $$ begin
  assert (select card_count from public.board_overview where id = '10000000-0000-0000-0000-000000000001') = 2, 'card_count';
  assert (select contact_count from public.board_overview where id = '10000000-0000-0000-0000-000000000001') = 1, 'contact_count';
  assert (select jsonb_array_length(previews) from public.board_overview where id = '10000000-0000-0000-0000-000000000001') = 1, 'previews';
  assert (select is_owner from public.board_overview where id = '10000000-0000-0000-0000-000000000001'), 'is_owner';
end $$;

-- Share links: read OK, edit needs premium.
insert into public.board_shares (board_id, access, token) values
  ('10000000-0000-0000-0000-000000000001', 'read', 'tok-read');
do $$ begin
  insert into public.board_shares (board_id, access) values ('10000000-0000-0000-0000-000000000001', 'edit');
  raise exception 'TEST FAILED: edit share needs premium';
exception when others then
  if sqlerrm <> 'KEEVY_PREMIUM_REQUIRED_EDIT_SHARE' then raise; end if;
end $$;

-- ── Premium upgrade (what the RevenueCat webhook does, as service role) ─────
reset role;
update public.profiles set is_premium = true where id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
insert into public.board_shares (board_id, access, token) values
  ('10000000-0000-0000-0000-000000000001', 'edit', 'tok-edit');
update public.boards set archived_at = null where id = '10000000-0000-0000-0000-000000000003';
insert into public.boards (name, mode) values ('Anniversaire', 'projet');

-- ── Anonymous web viewer ────────────────────────────────────────────────────
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
declare v jsonb;
begin
  v := public.get_shared_board('tok-read');
  assert v is not null, 'shared board visible with a valid token';
  assert v -> 'board' ->> 'name' = 'Mariage', 'shared board name';
  assert jsonb_array_length(v -> 'cards') = 2, 'shared cards';
  assert jsonb_array_length(v -> 'sections') = 1, 'shared sections';
  assert (v -> 'board') ? 'owner_id' = false, 'owner id hidden';
  assert public.get_shared_board('nope') is null, 'invalid token';
  assert (select count(*) from public.boards) = 0, 'anon sees no boards';
  assert (select count(*) from public.contacts) = 0, 'anon sees no contacts';
end $$;

-- ── Bob: stranger, then collaborator ────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
do $$ begin
  assert (select count(*) from public.boards) = 0, 'bob sees no boards';
  assert (select count(*) from public.board_shares) = 0, 'bob sees no share tokens';
end $$;
do $$ begin
  insert into public.cards (board_id, kind, body) values ('10000000-0000-0000-0000-000000000001', 'note', 'hack');
  raise exception 'TEST FAILED: stranger insert';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform public.accept_board_share('tok-read');
  raise exception 'TEST FAILED: read link must not grant membership';
exception when others then
  if sqlerrm <> 'KEEVY_SHARE_READ_ONLY' then raise; end if;
end $$;
select public.accept_board_share('tok-edit');
do $$ begin
  assert (select count(*) from public.boards) = 1, 'bob sees the shared board';
  assert (select is_owner from public.board_overview where id = '10000000-0000-0000-0000-000000000001') = false, 'not owner';
  assert (select count(*) from public.contacts) = 1, 'bob sees vendors linked to the board';
end $$;
insert into public.cards (board_id, kind, body) values ('10000000-0000-0000-0000-000000000001', 'note', 'Idée de Bob');
-- Bob cannot rename or delete Alice's board, nor edit her contacts.
update public.boards set name = 'pwned' where id = '10000000-0000-0000-0000-000000000001';
delete from public.boards where id = '10000000-0000-0000-0000-000000000001';
update public.contacts set name = 'pwned' where id = '30000000-0000-0000-0000-000000000001';
-- Storage: member may upload into the board folder.
insert into storage.objects (bucket_id, name) values ('card-images', '10000000-0000-0000-0000-000000000001/bob.jpg');
do $$ begin
  insert into storage.objects (bucket_id, name) values ('card-images', 'not-a-uuid/x.jpg');
  raise exception 'TEST FAILED: storage garbage path';
exception when insufficient_privilege then null;
end $$;

-- ── Carol: stranger ─────────────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
do $$ begin
  assert (select count(*) from public.boards) = 0, 'carol sees no boards';
  assert (select count(*) from public.contacts) = 0, 'carol sees no contacts';
  assert (select count(*) from public.cards) = 0, 'carol sees no cards';
  assert (select count(*) from storage.objects) = 0, 'carol sees no images';
end $$;
do $$ begin
  insert into storage.objects (bucket_id, name) values ('card-images', '10000000-0000-0000-0000-000000000001/carol.jpg');
  raise exception 'TEST FAILED: stranger upload';
exception when insufficient_privilege then null;
end $$;

-- ── Final checks as superuser ───────────────────────────────────────────────
reset role;
do $$ begin
  assert (select name from public.boards where id = '10000000-0000-0000-0000-000000000001') = 'Mariage', 'board not renamed by member';
  assert (select name from public.contacts where id = '30000000-0000-0000-0000-000000000001') = 'Atelier Rosa', 'contact not edited by member';
  assert (select count(*) from public.cards where board_id = '10000000-0000-0000-0000-000000000001') = 3, 'member card inserted';
end $$;

select 'KEEVY RLS SMOKE TEST: ALL PASSED' as result;
rollback;
