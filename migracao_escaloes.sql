-- Migração mínima (só ACRESCENTA a tabela categories; não altera nenhuma tabela existente).
-- Alternativa a correr o supabase_schema.sql completo.

-- Escalões / categorias configuráveis pelo admin (acrescentado; idempotente).
-- A app tem uma lista de categorias por defeito; as linhas desta tabela sobrepõem-se
-- a essa lista (editar, criar novos escalões, ocultar). Tabela vazia = comportamento antigo.
create table if not exists categories (
  id text primary key,                         -- igual ao cat_id usado em players/matches/tournaments
  name text not null,
  description text,
  icon text,
  color text,                                  -- classes Tailwind do gradiente
  sport text not null default 'tenis',         -- 'tenis' (individual) | 'padel' (duplas)
  sort_order int not null default 100,
  active boolean not null default true,        -- false = oculto (nada é apagado)
  format_rule text not null default 'standard',-- 'standard' | 'juvenis'
  schedule_mode text not null default 'weekly',-- 'weekly' | 'saturday'
  match_days jsonb,                            -- ["YYYY-MM-DD", ...] sábados de jogo
  day_start text default '14:30',
  day_end text default '19:30',
  match_minutes int default 20,
  courts int default 2,
  updated_at timestamptz not null default now()
);

alter table categories enable row level security;

-- categories: leitura pública, escrita só admin.
drop policy if exists "public read categories" on categories;
drop policy if exists "admin write categories" on categories;
drop policy if exists "admin update categories" on categories;
drop policy if exists "admin delete categories" on categories;
create policy "public read categories" on categories for select using (true);
create policy "admin write categories" on categories for insert with check (is_admin());
create policy "admin update categories" on categories for update using (is_admin());
create policy "admin delete categories" on categories for delete using (is_admin());

