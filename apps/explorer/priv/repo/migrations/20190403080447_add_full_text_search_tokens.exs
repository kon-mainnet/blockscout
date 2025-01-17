defmodule Explorer.Repo.Migrations.AddFullTextSearchTokens do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    execute("""
    CREATE INDEX IF NOT EXISTS tokens_trgm_idx ON tokens USING GIN (to_tsvector('english', symbol || ' ' || name))
    """)
  end

  def down do
    execute("DROP INDEX tokens_trgm_idx")
    execute("DROP EXTENSION pg_trgm")
  end
end
