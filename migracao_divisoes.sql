-- ============================================================
-- Migração: DIVISÕES nos escalões de ténis
-- (ATP Masters 1000 > ATP Challenger > ITF Tennis Tour)
--
-- Só ACRESCENTA colunas/tabelas. Não altera nem apaga nenhum dado
-- existente: torneios a decorrer, jogos, resultados, inscrições e
-- contas ficam exatamente como estão. Idempotente (pode correr-se
-- várias vezes). Também está incluída no supabase_schema.sql.
-- ============================================================

-- Uma divisão é um escalão (linha de `categories`) ligado ao escalão "pai".
-- Escalões já existentes ficam com parent_id/division a null = escalão normal.
alter table categories add column if not exists parent_id text;   -- id do escalão pai (ex.: 'tenis-senior-masc')
alter table categories add column if not exists division int;     -- 1 = ATP Masters 1000, 2 = ATP Challenger, 3 = ITF Tennis Tour

-- Marca que as subidas/descidas de um torneio de divisão já foram aplicadas
-- (evita aplicar duas vezes). Ao reiniciar o torneio a linha é apagada e o
-- marcador volta a false na época seguinte. Torneios existentes: false.
alter table tournaments add column if not exists divisions_applied boolean not null default false;

-- Divisão atribuída a cada pessoa (por email/conta) em cada escalão com divisões.
-- Persiste entre torneios (como as contas). A 1ª atribuição é feita pelo admin;
-- depois as subidas/descidas atualizam-na automaticamente.
create table if not exists player_divisions (
  email text not null,
  group_id text not null,                      -- id do escalão pai
  division int not null check (division between 1 and 3),
  assigned_by text not null default 'admin',   -- 'admin' | 'auto'
  updated_at timestamptz not null default now(),
  primary key (email, group_id)
);

-- Histórico das subidas/descidas (e alterações manuais do admin).
create table if not exists division_history (
  id text primary key,
  group_id text not null,
  email text not null,
  player_name text,
  from_division int,
  to_division int,
  reason text,                                 -- 'promocao' | 'despromocao' | 'manutencao' | 'admin'
  source_cat_id text,                          -- torneio (divisão) que originou o movimento
  created_at timestamptz not null default now()
);

alter table player_divisions enable row level security;
alter table division_history enable row level security;

drop policy if exists "public read player_divisions" on player_divisions;
drop policy if exists "admin write player_divisions" on player_divisions;
drop policy if exists "admin update player_divisions" on player_divisions;
drop policy if exists "admin delete player_divisions" on player_divisions;
create policy "public read player_divisions" on player_divisions for select using (true);
create policy "admin write player_divisions" on player_divisions for insert with check (is_admin());
create policy "admin update player_divisions" on player_divisions for update using (is_admin());
create policy "admin delete player_divisions" on player_divisions for delete using (is_admin());

drop policy if exists "public read division_history" on division_history;
drop policy if exists "admin write division_history" on division_history;
drop policy if exists "admin delete division_history" on division_history;
create policy "public read division_history" on division_history for select using (true);
create policy "admin write division_history" on division_history for insert with check (is_admin());
create policy "admin delete division_history" on division_history for delete using (is_admin());

-- Ao mudar o email de uma conta, a divisão acompanha-a.
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
  update player_divisions set email = v_new where email = v_old;
  update division_history set email = v_new where email = v_old;
end;
$$;

revoke all on function change_account_email(text, text) from public, anon, authenticated;
