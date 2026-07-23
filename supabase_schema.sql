-- ============================================================
-- EMTP 2026 - Schema Supabase
-- Corre este script inteiro no SQL Editor do teu projeto Supabase
-- (https://app.supabase.com/project/_/sql/new)
-- Podes correr este script várias vezes sem erro (é idempotente).
-- ============================================================

-- ---------- TABELAS ----------

create table if not exists players (
  id text primary key,
  cat_id text not null,
  name text not null,
  type text not null,               -- 'single' | 'doubles'
  sport text not null,              -- 'tenis' | 'padel'
  email text,
  phone text,
  partner_name text,
  registered_at timestamptz not null default now()
);

create table if not exists matches (
  id text primary key,
  cat_id text not null,
  jornada int not null,
  p1 text not null,
  p2 text not null,
  set1_p1 int,
  set1_p2 int,
  set2_p1 int,
  set2_p2 int,
  set3_p1 int,
  set3_p2 int,
  super_tb boolean not null default false,
  completed boolean not null default false,
  wo_player text,
  updated_at timestamptz not null default now()
);

create table if not exists messages (
  id text primary key,
  channel_id text not null,          -- 'global' ou id de categoria
  author_id text,
  author_name text,
  author_role text,
  text text,
  type text,
  timestamp timestamptz not null default now(),
  suggested_date text,
  suggested_time text,
  suggested_location text,
  reschedule_response text,
  reschedule_responder text
);

create table if not exists inscriptions (
  id text primary key,
  player_id text,
  player_name text not null,
  cat_id text not null,
  type text not null,
  sport text not null,
  email text,
  phone text,
  partner_name text,
  status text not null default 'confirmed',
  registered_at timestamptz not null default now()
);

create table if not exists playoffs (
  cat_id text primary key,
  semi1 jsonb,
  semi2 jsonb,
  final jsonb,
  third jsonb
);

-- Perfis ligados ao Supabase Auth (usado para saber quem é admin)
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'player'   -- 'admin' | 'player'
);

-- ---------- ROW LEVEL SECURITY ----------
-- A app usa a anon key diretamente no browser (sem backend próprio). Os
-- atletas não têm sessão real do Supabase Auth (login próprio via RPC),
-- por isso inserts/updates em players/messages/inscriptions continuam
-- públicos (é como eles conseguem inscrever-se e falar no chat). Operações
-- destrutivas ou sensíveis (apagar registos, escrever resultados de jogos)
-- passam a exigir sessão de admin (ver is_admin() abaixo).

alter table players enable row level security;
alter table matches enable row level security;
alter table messages enable row level security;
alter table inscriptions enable row level security;
alter table playoffs enable row level security;
alter table profiles enable row level security;

-- profiles: qualquer utilizador autenticado só lê o seu próprio perfil
drop policy if exists "read own profile" on profiles;
create policy "read own profile" on profiles for select using (auth.uid() = id);

-- Helper: true se quem está a fazer o pedido está autenticado (supabase.auth)
-- como admin. Não precisa de "security definer" porque a policy "read own
-- profile" acima já deixa um utilizador autenticado ler a sua própria linha;
-- para um visitante sem sessão, auth.uid() é null e a condição nunca bate certo.
create or replace function is_admin()
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

grant execute on function is_admin() to anon, authenticated;

-- players: leitura, criação e atualização continuam públicas (o admin cria
-- atletas e os próprios atletas movem-se de categoria ao inscrever-se, sem
-- sessão real do Supabase Auth). Apagar um atleta passa a exigir admin.
drop policy if exists "public read players" on players;
drop policy if exists "public write players" on players;
drop policy if exists "public update players" on players;
drop policy if exists "public delete players" on players;
drop policy if exists "admin delete players" on players;
create policy "public read players" on players for select using (true);
create policy "public write players" on players for insert with check (true);
create policy "public update players" on players for update using (true);
create policy "admin delete players" on players for delete using (is_admin());

-- matches: leitura pública (todos veem resultados), mas escrever/editar/apagar
-- resultados passa a exigir admin (já era 100% admin-only na interface).
drop policy if exists "public read matches" on matches;
drop policy if exists "public write matches" on matches;
drop policy if exists "public update matches" on matches;
drop policy if exists "public delete matches" on matches;
drop policy if exists "admin write matches" on matches;
drop policy if exists "admin update matches" on matches;
drop policy if exists "admin delete matches" on matches;
create policy "public read matches" on matches for select using (true);
create policy "admin write matches" on matches for insert with check (is_admin());
create policy "admin update matches" on matches for update using (is_admin());
create policy "admin delete matches" on matches for delete using (is_admin());

-- messages: continuam com escrita pública (chat/reagendamentos dos atletas,
-- sem sessão real do Supabase Auth). Apagar mensagens passa a exigir admin.
drop policy if exists "public read messages" on messages;
drop policy if exists "public write messages" on messages;
drop policy if exists "public update messages" on messages;
drop policy if exists "public delete messages" on messages;
drop policy if exists "admin delete messages" on messages;
create policy "public read messages" on messages for select using (true);
create policy "public write messages" on messages for insert with check (true);
create policy "public update messages" on messages for update using (true);
create policy "admin delete messages" on messages for delete using (is_admin());

-- inscriptions: continuam com escrita pública (inscrição feita pelo próprio
-- atleta ou pelo admin). Apagar inscrições passa a exigir admin.
drop policy if exists "public read inscriptions" on inscriptions;
drop policy if exists "public write inscriptions" on inscriptions;
drop policy if exists "public update inscriptions" on inscriptions;
drop policy if exists "public delete inscriptions" on inscriptions;
drop policy if exists "admin delete inscriptions" on inscriptions;
create policy "public read inscriptions" on inscriptions for select using (true);
create policy "public write inscriptions" on inscriptions for insert with check (true);
create policy "public update inscriptions" on inscriptions for update using (true);
create policy "admin delete inscriptions" on inscriptions for delete using (is_admin());

drop policy if exists "public read playoffs" on playoffs;
drop policy if exists "public write playoffs" on playoffs;
drop policy if exists "public update playoffs" on playoffs;
create policy "public read playoffs" on playoffs for select using (true);
create policy "public write playoffs" on playoffs for insert with check (true);
create policy "public update playoffs" on playoffs for update using (true);

-- ---------- CREDENCIAIS DOS ATLETAS (email + password) ----------
-- Cada atleta passa a ter um email gerado (nome.sobrenome@emtp.com, com
-- número a seguir se já existir) e uma password. A password NUNCA é
-- guardada em texto simples nem na tabela `players` (que é de leitura
-- pública) — fica hashed (bcrypt via pgcrypto) numa tabela à parte, sem
-- nenhuma policy pública de leitura. Só é acedida através das funções
-- abaixo (security definer), nunca diretamente pelo browser.

-- No Supabase, o pgcrypto instala-se no schema "extensions" (não no "public"),
-- por isso as funções abaixo têm de incluir "extensions" no search_path.
create extension if not exists pgcrypto with schema extensions;

create table if not exists player_credentials (
  player_id text primary key references players(id) on delete cascade,
  password_hash text not null,
  updated_at timestamptz not null default now()
);

alter table player_credentials enable row level security;
-- Sem policies = ninguém (nem com a anon key) consegue ler/escrever
-- diretamente nesta tabela. Só as funções "security definer" abaixo,
-- que correm com privilégios do dono da função, conseguem.

-- Define a password de um atleta que AINDA NÃO tem credenciais
-- (usada na criação do atleta). Falha se já existirem credenciais,
-- para nunca poder ser usada para sobrescrever uma password existente.
create or replace function create_player_credentials(p_player_id text, p_password text)
returns void
language sql
security definer
set search_path = public, extensions
as $$
  insert into player_credentials (player_id, password_hash)
  values (p_player_id, crypt(p_password, gen_salt('bf')));
$$;

-- Confirma se a password dada corresponde à guardada (uso interno).
create or replace function verify_player_password(p_player_id text, p_password text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from player_credentials
    where player_id = p_player_id
      and password_hash = crypt(p_password, password_hash)
  );
$$;

-- O próprio atleta muda a password, tem de indicar a password atual.
create or replace function change_player_password(p_player_id text, p_old_password text, p_new_password text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not verify_player_password(p_player_id, p_old_password) then
    return false;
  end if;
  update player_credentials
    set password_hash = crypt(p_new_password, gen_salt('bf')), updated_at = now()
    where player_id = p_player_id;
  return true;
end;
$$;

-- O admin repõe a password de qualquer atleta, sem saber a antiga.
-- Só funciona se quem chamar estiver autenticado (supabase.auth) como admin.
create or replace function admin_reset_player_password(p_player_id text, p_new_password text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Apenas o administrador pode repor passwords.';
  end if;
  insert into player_credentials (player_id, password_hash, updated_at)
  values (p_player_id, crypt(p_new_password, gen_salt('bf')), now())
  on conflict (player_id) do update
    set password_hash = excluded.password_hash, updated_at = now();
end;
$$;

-- Login do atleta: recebe email+password, devolve o player_id se corresponder
-- (ou null). Usado no ecrã "Entrar como Atleta".
create or replace function login_player(p_email text, p_password text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_player_id text;
begin
  select id into v_player_id from players where lower(email) = lower(p_email) limit 1;
  if v_player_id is null then
    return null;
  end if;
  if verify_player_password(v_player_id, p_password) then
    return v_player_id;
  else
    return null;
  end if;
end;
$$;

-- Permitir que a app (anon key) chame estas funções via RPC.
grant execute on function create_player_credentials(text, text) to anon, authenticated;
grant execute on function change_player_password(text, text, text) to anon, authenticated;
grant execute on function admin_reset_player_password(text, text) to anon, authenticated;
grant execute on function login_player(text, text) to anon, authenticated;
-- verify_player_password fica só para uso interno das outras funções
-- (não é preciso conceder execute a anon).

-- ---------- REALTIME ----------
-- Necessário para que app.setupRealtime() receba INSERT/UPDATE ao vivo.
-- Envolvido em DO blocks para não rebentar se a tabela já estiver na publication.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'players'
  ) then
    alter publication supabase_realtime add table players;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'matches'
  ) then
    alter publication supabase_realtime add table matches;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table messages;
  end if;
end $$;
