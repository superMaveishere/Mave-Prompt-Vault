create extension if not exists pgcrypto;

do $$ begin create type public.app_rank as enum('USER','VIP','OWNER'); exception when duplicate_object then null; end $$;
do $$ begin create type public.prompt_access as enum('PUBLIC','VIP','OWNER'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null,
 display_name text not null,
 rank public.app_rank not null default 'USER',
 avatar_url text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.prompts(
 id uuid primary key default gen_random_uuid(), title text not null,
 author_id uuid references public.profiles(id) on delete set null,
 author_name text not null, ai_name text not null, image_url text,
 date date not null default current_date,
 access public.prompt_access not null default 'PUBLIC', price integer not null default 0 check(price>=0),
 description text not null default '', prompt_text text not null,
 published boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.reviews(
 id uuid primary key default gen_random_uuid(), prompt_id uuid not null references public.prompts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade, reviewer_name text not null,
 rating integer not null check(rating between 1 and 5), review_text text not null,
 created_at timestamptz not null default now(), unique(prompt_id,user_id)
);
create table if not exists public.feedback(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 name text not null, type text not null check(type in('Kritik','Saran','Bug Report','Ide Fitur')), message text not null, created_at timestamptz not null default now()
);
create table if not exists public.updates(
 id uuid primary key default gen_random_uuid(), title text not null, description text not null default '', image_url text,
 date date not null default current_date, published boolean not null default false,
 created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.featured_slots(slot smallint primary key check(slot between 1 and 3),prompt_id uuid references public.prompts(id) on delete set null,updated_by uuid references public.profiles(id) on delete set null,updated_at timestamptz not null default now());
insert into public.featured_slots(slot) values(1),(2),(3) on conflict do nothing;
create table if not exists public.activity_logs(id bigint generated always as identity primary key,actor_id uuid references public.profiles(id) on delete set null,action text not null,detail text,created_at timestamptz not null default now());
create table if not exists public.settings(key text primary key,value text not null default '',updated_by uuid references public.profiles(id) on delete set null,updated_at timestamptz not null default now());
insert into public.settings(key,value) values('site_name','Mave Vault'),('whatsapp_owner','') on conflict do nothing;

create or replace function public.current_rank() returns public.app_rank language sql stable security definer set search_path=public as $$select rank from public.profiles where id=auth.uid()$$;
create or replace function public.is_owner() returns boolean language sql stable security definer set search_path=public as $$select coalesce(public.current_rank()='OWNER',false)$$;
create or replace function public.is_vip_or_owner() returns boolean language sql stable security definer set search_path=public as $$select coalesce(public.current_rank() in('VIP','OWNER'),false)$$;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,username,display_name) values(new.id,coalesce(nullif(new.raw_user_meta_data->>'username',''),'user_'||substr(new.id::text,1,8)),coalesce(nullif(new.raw_user_meta_data->>'display_name',''),'User')); return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security; alter table public.prompts enable row level security; alter table public.reviews enable row level security; alter table public.feedback enable row level security; alter table public.updates enable row level security; alter table public.featured_slots enable row level security; alter table public.activity_logs enable row level security; alter table public.settings enable row level security;

drop policy if exists profiles_self on public.profiles; create policy profiles_self on public.profiles for select to authenticated using(id=auth.uid() or public.is_owner());
drop policy if exists profiles_update on public.profiles; create policy profiles_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid() and rank=public.current_rank());
drop policy if exists profiles_owner_update on public.profiles; create policy profiles_owner_update on public.profiles for update to authenticated using(public.is_owner()) with check(public.is_owner());

drop policy if exists prompts_visible on public.prompts; create policy prompts_visible on public.prompts for select using(published=true and(access='PUBLIC' or(access='VIP' and public.is_vip_or_owner()) or(access='OWNER' and public.is_owner())));
drop policy if exists prompts_owner on public.prompts; create policy prompts_owner on public.prompts for all to authenticated using(public.is_owner()) with check(public.is_owner());

drop policy if exists reviews_visible on public.reviews; create policy reviews_visible on public.reviews for select using(exists(select 1 from public.prompts p where p.id=prompt_id and p.published=true));
drop policy if exists reviews_insert on public.reviews; create policy reviews_insert on public.reviews for insert to authenticated with check(user_id=auth.uid());
drop policy if exists reviews_owner on public.reviews; create policy reviews_owner on public.reviews for all to authenticated using(public.is_owner()) with check(public.is_owner());

drop policy if exists feedback_insert on public.feedback; create policy feedback_insert on public.feedback for insert to authenticated with check(user_id=auth.uid());
drop policy if exists feedback_owner on public.feedback; create policy feedback_owner on public.feedback for all to authenticated using(public.is_owner()) with check(public.is_owner());

drop policy if exists updates_visible on public.updates; create policy updates_visible on public.updates for select using(published=true);
drop policy if exists updates_owner on public.updates; create policy updates_owner on public.updates for all to authenticated using(public.is_owner()) with check(public.is_owner());

drop policy if exists featured_read on public.featured_slots; create policy featured_read on public.featured_slots for select using(true);
drop policy if exists featured_owner on public.featured_slots; create policy featured_owner on public.featured_slots for all to authenticated using(public.is_owner()) with check(public.is_owner());

drop policy if exists logs_owner on public.activity_logs; create policy logs_owner on public.activity_logs for select to authenticated using(public.is_owner());
drop policy if exists settings_public on public.settings; create policy settings_public on public.settings for select using(key='site_name');
drop policy if exists settings_owner on public.settings; create policy settings_owner on public.settings for all to authenticated using(public.is_owner()) with check(public.is_owner());

create or replace view public.prompt_rating_summary with(security_invoker=true) as select p.id prompt_id,coalesce(round(avg(r.rating)::numeric,2),0) average_rating,count(r.id)::integer review_count from public.prompts p left join public.reviews r on r.prompt_id=p.id group by p.id;

-- Storage bucket: public URLs are used by the frontend. Upload/delete remains Owner-only through RLS.
insert into storage.buckets(id,name,public) values('vault-media','vault-media',true) on conflict(id) do update set public=true;

drop policy if exists vault_media_read on storage.objects; create policy vault_media_read on storage.objects for select using(bucket_id='vault-media');
drop policy if exists vault_media_owner_insert on storage.objects; create policy vault_media_owner_insert on storage.objects for insert to authenticated with check(bucket_id='vault-media' and public.is_owner());
drop policy if exists vault_media_owner_update on storage.objects; create policy vault_media_owner_update on storage.objects for update to authenticated using(bucket_id='vault-media' and public.is_owner()) with check(bucket_id='vault-media' and public.is_owner());
drop policy if exists vault_media_owner_delete on storage.objects; create policy vault_media_owner_delete on storage.objects for delete to authenticated using(bucket_id='vault-media' and public.is_owner());
