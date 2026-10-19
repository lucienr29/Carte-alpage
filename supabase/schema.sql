-- Modifications partagées de la carte de l'alpage
create table if not exists public.modifs (
  cle   text primary key,            -- repère de l'élément (V1, C3, F42…)
  props jsonb not null default '{}', -- attributs modifiés
  maj   timestamptz not null default now(),
  par   text,
  geom  jsonb                         -- géométrie redessinée (GeoJSON), sinon celle du plan
);
create table if not exists public.editeurs (email text primary key);

alter table public.modifs enable row level security;
alter table public.editeurs enable row level security;
-- editeurs : aucune policy, donc illisible et non modifiable depuis le site

-- Lit la liste des éditeurs avec les droits du propriétaire (la table est fermée au site)
create or replace function public.est_editeur() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.editeurs e where lower(e.email) = lower(auth.jwt() ->> 'email'));
$$;
revoke execute on function public.est_editeur() from public, anon;
grant execute on function public.est_editeur() to authenticated;

-- Seuls les éditeurs lisent et écrivent directement ; les visiteurs lisent avec le mot de passe de l'alpage (lire_modifs)
create policy "lecture editeurs" on public.modifs for select to authenticated using ((select public.est_editeur()));
create policy "ajout editeurs" on public.modifs for insert to authenticated with check ((select public.est_editeur()));
create policy "maj editeurs" on public.modifs for update to authenticated using ((select public.est_editeur())) with check ((select public.est_editeur()));
create policy "suppression editeurs" on public.modifs for delete to authenticated using ((select public.est_editeur()));

alter publication supabase_realtime add table public.modifs;

-- 2026-10-19 : plusieurs sites (alpages, vignes) dans la même table
alter table public.modifs add column if not exists site text not null default 'serin';
alter table public.modifs drop constraint modifs_pkey;
alter table public.modifs add primary key (site, cle);

-- 2026-10-19 : un mot de passe par alpage (hash bcrypt, jamais en clair)
create table if not exists public.sites (site text primary key, mdp_hash text not null);
alter table public.sites enable row level security;  -- aucune policy : illisible depuis le site
revoke all on public.sites from anon, authenticated;
-- Changer un mot de passe : update public.sites set mdp_hash = extensions.crypt('NOUVEAU', extensions.gen_salt('bf', 10)) where site = 'serin';
-- (et reconstruire la page, car le plan est chiffré avec le même mot de passe)

create or replace function public.lire_modifs(p_site text, p_mdp text)
returns setof public.modifs
language plpgsql security definer set search_path = ''
as $$
begin
  if not exists (select 1 from public.sites s where s.site = p_site and s.mdp_hash = extensions.crypt(p_mdp, s.mdp_hash)) then
    raise exception 'mot de passe incorrect' using errcode = '28P01';
  end if;
  return query select * from public.modifs m where m.site = p_site;
end $$;
revoke all on function public.lire_modifs(text, text) from public;
grant execute on function public.lire_modifs(text, text) to anon, authenticated;
