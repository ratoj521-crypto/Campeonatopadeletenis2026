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
  nif text,
  address text,
  partner_name text,
  partner_email text,               -- email do 2º jogador (Padel), que também tem conta
  registered_at timestamptz not null default now()
);

-- Colunas acrescentadas (bases de dados já existentes; idempotente).
alter table players add column if not exists nif text;
alter table players add column if not exists address text;
alter table players add column if not exists partner_email text;

-- Contas (pessoas registadas na app). PERSISTEM ao reiniciar torneios.
-- A participação num torneio (linha em `players`) é que é limpa no reinício.
create table if not exists accounts (
  email text primary key,
  name text,
  nif text,
  address text,
  phone text,
  created_at timestamptz not null default now()
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

-- Colunas de formato dos jogos (acrescentadas; idempotente e retrocompatível).
-- Jogos já existentes ficam com phase='group', leg=1 e group_idx nulo — ou seja,
-- exatamente o que eram antes: fase de grupos, uma mão, grupo único.
alter table matches add column if not exists phase text not null default 'group';  -- 'group' | 'final'
alter table matches add column if not exists group_idx int;                        -- 0 ou 1 quando há dois grupos; null se grupo único
alter table matches add column if not exists leg int not null default 1;           -- 1ª ou 2ª mão
alter table matches add column if not exists round_idx int;                        -- ronda do quadro final (0 = primeira)
alter table matches add column if not exists label text;                           -- 'Meia-final 1', 'Finalíssima', '3º/4º lugar', ...

-- Marcação do jogo (dia/hora/local combinados entre os adversários ou definidos pelo admin).
-- Nulo = ainda por marcar (vale a janela de datas da jornada).
alter table matches add column if not exists scheduled_date date;
alter table matches add column if not exists scheduled_time text;                  -- 'HH:MM'
alter table matches add column if not exists scheduled_location text;

create table if not exists messages (
  id text primary key,
  channel_id text not null,          -- 'global', id de categoria, 'dm:<email>' ou 'match:<id do jogo>'
  author_id text,
  author_name text,
  author_role text,
  text text,
  type text,
  timestamp timestamptz not null default now(),
  suggested_date text,
  suggested_time text,
  suggested_location text,
  reschedule_response text,          -- null (pendente) | 'accepted' | 'rejected' | 'countered' | 'superseded'
  reschedule_responder text
);

create table if not exists inscriptions (
  id text primary key,
  player_id text,
  player_name text not null,
  cat_id text not null,
  categories text,                   -- lista de categorias (Padel pode ter várias), separadas por vírgula
  type text not null,
  sport text not null,
  nif text,                          -- NIF do jogador 1
  address text,                      -- morada do jogador 1
  email text,
  phone text,
  partner_name text,                 -- jogador 2 (Padel)
  partner_nif text,
  partner_address text,
  partner_email text,
  partner_phone text,
  temp_password text,                -- password temporária do jogador 1 (o admin entrega-a; o atleta altera no 1º login)
  partner_temp_password text,        -- password temporária do jogador 2 (Padel)
  status text not null default 'confirmed',
  registered_at timestamptz not null default now()
);

-- Colunas acrescentadas (para bases de dados já existentes; idempotente).
alter table inscriptions add column if not exists categories text;
alter table inscriptions add column if not exists nif text;
alter table inscriptions add column if not exists address text;
alter table inscriptions add column if not exists partner_nif text;
alter table inscriptions add column if not exists partner_address text;
alter table inscriptions add column if not exists partner_email text;
alter table inscriptions add column if not exists partner_phone text;
alter table inscriptions add column if not exists temp_password text;
alter table inscriptions add column if not exists partner_temp_password text;
-- player_id deixa de ser usado (inscrição pública sem login); torna-se opcional.
alter table inscriptions alter column player_id drop not null;

create table if not exists playoffs (
  cat_id text primary key,
  semi1 jsonb,
  semi2 jsonb,
  final jsonb,
  third jsonb
);

-- Torneio por categoria: datas e estado (iniciado ou não).
create table if not exists tournaments (
  cat_id text primary key,
  start_date date,
  end_date date,
  started boolean not null default false,
  updated_at timestamptz not null default now()
);

-- Formato do torneio por categoria (acrescentado; idempotente e retrocompatível).
-- Os valores por defeito reproduzem exatamente o comportamento antigo:
-- um grupo único, todos-contra-todos a uma mão e sem fase final.
alter table tournaments add column if not exists legs int not null default 1;                 -- 1 = uma mão, 2 = duas mãos (fase de grupos)
alter table tournaments add column if not exists num_groups int not null default 1;            -- 1 ou 2 grupos
alter table tournaments add column if not exists qualifiers_per_group int not null default 2;  -- quantos passam de cada grupo
alter table tournaments add column if not exists final_legs int not null default 1;            -- 1 = fase final a uma mão, 2 = ida e volta
alter table tournaments add column if not exists final_type text not null default 'none';      -- 'none' | 'bracket' | 'minigroup' | 'single'
alter table tournaments add column if not exists groups jsonb;                                  -- [[playerId,...], [playerId,...]] — sorteio dos grupos
alter table tournaments add column if not exists final_seeds jsonb;                             -- ordem de apuramento fixada ao gerar a fase final
alter table tournaments add column if not exists final_started boolean not null default false;  -- fase final já gerada
alter table tournaments add column if not exists planned_jornadas int;                          -- total de jornadas previstas (grupos + fase final)
alter table tournaments add column if not exists capacity int;                                  -- lotação da categoria (null = valor por defeito da app)

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
alter table tournaments enable row level security;
alter table accounts enable row level security;

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

-- matches: leitura pública. A escrita/atualização de resultados é PÚBLICA porque
-- os atletas (que reportam o resultado do seu jogo) não têm sessão real do Supabase
-- Auth — as regras (só o próprio jogo, dentro do prazo, contestar em vez de editar)
-- são aplicadas no cliente, como já acontece com players/messages/inscriptions.
-- Apagar jogos continua a exigir admin.
drop policy if exists "public read matches" on matches;
drop policy if exists "public write matches" on matches;
drop policy if exists "public update matches" on matches;
drop policy if exists "public delete matches" on matches;
drop policy if exists "admin write matches" on matches;
drop policy if exists "admin update matches" on matches;
drop policy if exists "admin delete matches" on matches;
create policy "public read matches" on matches for select using (true);
create policy "public write matches" on matches for insert with check (true);
create policy "public update matches" on matches for update using (true);
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

-- tournaments: leitura pública (todos veem as datas), mas iniciar/alterar o torneio é só admin.
drop policy if exists "public read tournaments" on tournaments;
drop policy if exists "admin write tournaments" on tournaments;
drop policy if exists "admin update tournaments" on tournaments;
drop policy if exists "admin delete tournaments" on tournaments;
create policy "public read tournaments" on tournaments for select using (true);
create policy "admin write tournaments" on tournaments for insert with check (is_admin());
create policy "admin update tournaments" on tournaments for update using (is_admin());
create policy "admin delete tournaments" on tournaments for delete using (is_admin());

-- accounts: leitura/criação/atualização públicas (registo feito pelo próprio,
-- sem sessão Supabase). Apagar contas é só admin. As contas persistem ao reiniciar.
drop policy if exists "public read accounts" on accounts;
drop policy if exists "public write accounts" on accounts;
drop policy if exists "public update accounts" on accounts;
drop policy if exists "admin delete accounts" on accounts;
create policy "public read accounts" on accounts for select using (true);
create policy "public write accounts" on accounts for insert with check (true);
create policy "public update accounts" on accounts for update using (true);
create policy "admin delete accounts" on accounts for delete using (is_admin());

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

-- ---------- LOGINS POR EMAIL (cada pessoa = um email/username) ----------
-- Passa a haver uma conta por EMAIL (não por linha de jogador). Assim, numa
-- dupla de Padel os dois jogadores têm conta própria (dois emails), ambas a
-- apontar para a mesma "entrada" de competição (player_id). Cada um tem a sua
-- própria password e altera-a de forma independente.
create table if not exists player_logins (
  email text primary key,
  password_hash text not null,
  player_id text not null,
  updated_at timestamptz not null default now()
);

alter table player_logins enable row level security;
-- Sem policies = só as funções security-definer abaixo acedem.

-- A conta (login) passa a ser independente da participação num torneio: só
-- guarda email + password. Assim, quando se reinicia (limpa participações), a
-- conta mantém-se e a pessoa não precisa de se registar outra vez.
alter table player_logins alter column player_id drop not null;

-- Cria a conta de um email (não sobrescreve se já existir).
create or replace function create_login(p_email text, p_password text)
returns void
language sql
security definer
set search_path = public, extensions
as $$
  insert into player_logins (email, password_hash)
  values (lower(p_email), crypt(p_password, gen_salt('bf')))
  on conflict (email) do nothing;
$$;

-- Login por email: devolve o email (em minúsculas) se a password bater certo (senão null).
create or replace function login_player_v2(p_email text, p_password text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_hash text;
begin
  select password_hash into v_hash from player_logins where email = lower(p_email);
  if v_hash is null then return null; end if;
  if v_hash = crypt(p_password, v_hash) then return lower(p_email); else return null; end if;
end;
$$;

-- O próprio utilizador muda a sua password (tem de indicar a atual).
create or replace function change_login_password(p_email text, p_old_password text, p_new_password text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v_hash text;
begin
  select password_hash into v_hash from player_logins where email = lower(p_email);
  if v_hash is null or v_hash <> crypt(p_old_password, v_hash) then return false; end if;
  update player_logins set password_hash = crypt(p_new_password, gen_salt('bf')), updated_at = now()
    where email = lower(p_email);
  return true;
end;
$$;

-- O admin repõe a password de um email (sem saber a antiga).
create or replace function admin_reset_login(p_email text, p_new_password text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Apenas o administrador pode repor passwords.';
  end if;
  update player_logins set password_hash = crypt(p_new_password, gen_salt('bf')), updated_at = now()
    where email = lower(p_email);
end;
$$;

-- O admin apaga uma conta por completo: login, participações e dados da conta.
create or replace function admin_delete_account(p_email text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Apenas o administrador pode apagar contas.';
  end if;
  delete from player_logins where email = lower(p_email);
  delete from players where lower(email) = lower(p_email) or lower(partner_email) = lower(p_email);
  delete from accounts where email = lower(p_email);
end;
$$;

drop function if exists create_login(text, text, text);
grant execute on function create_login(text, text) to anon, authenticated;
grant execute on function admin_delete_account(text) to authenticated;
grant execute on function login_player_v2(text, text) to anon, authenticated;
grant execute on function change_login_password(text, text, text) to anon, authenticated;
grant execute on function admin_reset_login(text, text) to anon, authenticated;

-- ---------- ALTERAR O EMAIL DE UMA CONTA ----------
-- O email é a chave da conta (accounts), do login (player_logins) e está copiado
-- nas participações (players.email e players.partner_email). Mudá-lo tem de ser
-- atómico, senão a pessoa fica sem login ou com participações órfãs — por isso
-- vive aqui numa função e não em vários pedidos do browser.
-- Esta função NÃO é exposta ao anon: só as duas de cima (admin / próprio) a chamam.
create or replace function change_account_email(p_old_email text, p_new_email text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_old text := lower(trim(p_old_email));
  v_new text := lower(trim(p_new_email));
begin
  if v_new is null or v_new = '' or v_new !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Email inválido.';
  end if;
  if v_old = v_new then
    return;
  end if;
  if exists (select 1 from accounts where email = v_new)
     or exists (select 1 from player_logins where email = v_new) then
    raise exception 'Já existe uma conta com o email %.', v_new;
  end if;
  if not exists (select 1 from accounts where email = v_old)
     and not exists (select 1 from player_logins where email = v_old) then
    raise exception 'Não existe nenhuma conta com o email %.', v_old;
  end if;

  update player_logins set email = v_new, updated_at = now() where email = v_old;
  update accounts     set email = v_new where email = v_old;
  update players      set email = v_new where lower(email) = v_old;
  update players      set partner_email = v_new where lower(partner_email) = v_old;
end;
$$;

revoke all on function change_account_email(text, text) from public, anon, authenticated;

-- O admin altera o email de qualquer conta (precisa de sessão Supabase como admin).
create or replace function admin_change_account_email(p_old_email text, p_new_email text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Apenas o administrador pode alterar emails de contas.';
  end if;
  perform change_account_email(p_old_email, p_new_email);
end;
$$;

-- O próprio utilizador altera o seu email, confirmando a password atual.
create or replace function change_own_account_email(p_email text, p_password text, p_new_email text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v_hash text;
begin
  select password_hash into v_hash from player_logins where email = lower(trim(p_email));
  if v_hash is null or v_hash <> crypt(p_password, v_hash) then
    raise exception 'Password incorreta.';
  end if;
  perform change_account_email(p_email, p_new_email);
end;
$$;

grant execute on function admin_change_account_email(text, text) to authenticated;
grant execute on function change_own_account_email(text, text, text) to anon, authenticated;

-- Migração: importa as credenciais antigas (player_credentials, por player_id)
-- para o novo modelo por email, usando o email de cada jogador. Idempotente.
insert into player_logins (email, password_hash, player_id)
select lower(p.email), pc.password_hash, pc.player_id
from player_credentials pc
join players p on p.id = pc.player_id
where p.email is not null
on conflict (email) do nothing;

-- Migração: cria as contas (accounts) a partir dos jogadores já existentes,
-- para que quem já tinha participação passe a ter conta persistente. Idempotente.
insert into accounts (email, name, nif, address, phone)
select distinct on (lower(p.email)) lower(p.email), p.name, p.nif, p.address, p.phone
from players p
where p.email is not null
order by lower(p.email), p.registered_at
on conflict (email) do nothing;

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
