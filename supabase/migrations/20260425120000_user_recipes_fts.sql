-- Postgres FTS over user_recipes: stored generated tsvector + GIN index.
-- 'german' config covers stemming + stopwords for the app's UI language.

alter table user_recipes
  add column search_tsv tsvector
  generated always as (
    to_tsvector(
      'german',
      coalesce(title, '') || ' ' || coalesce(array_to_string(ingredients, ' '), '')
    )
  ) stored;

create index user_recipes_search_tsv_idx
  on user_recipes using gin (search_tsv);
