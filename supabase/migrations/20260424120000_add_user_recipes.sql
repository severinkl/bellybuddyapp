-- user_recipes: user-owned meal templates.

create table user_recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  ingredients text[] not null default '{}',
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table user_recipes enable row level security;

create policy "user_recipes: users read own"
  on user_recipes for select
  using (auth.uid() = user_id);

create policy "user_recipes: users insert own"
  on user_recipes for insert
  with check (auth.uid() = user_id);

create policy "user_recipes: users update own"
  on user_recipes for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "user_recipes: users delete own"
  on user_recipes for delete
  using (auth.uid() = user_id);

create index user_recipes_user_id_created_at_idx
  on user_recipes (user_id, created_at desc);
