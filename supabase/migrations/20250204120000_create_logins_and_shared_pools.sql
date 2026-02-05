-- SquareUp: logins (Apple/Google sign-in events) and shared_pools (invite codes)

-- =============================================================================
-- Table: logins
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.logins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL,
  provider_uid text NOT NULL,
  email text,
  display_name text,
  client_timestamp timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.logins ENABLE ROW LEVEL SECURITY;

-- Allow app (anon) to insert sign-in events only
CREATE POLICY "Allow anon to insert logins"
  ON public.logins
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Optional: allow service role / authenticated to read (e.g. for admin)
-- CREATE POLICY "Allow read for authenticated"
--   ON public.logins FOR SELECT TO authenticated USING (true);


-- =============================================================================
-- Table: shared_pools
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.shared_pools (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL,
  pool_json jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_shared_pools_code ON public.shared_pools (code);

ALTER TABLE public.shared_pools ENABLE ROW LEVEL SECURITY;

-- Allow app (anon) to insert when sharing a pool
CREATE POLICY "Allow anon to insert shared_pools"
  ON public.shared_pools
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Allow app (anon) to select by code when joining
CREATE POLICY "Allow anon to select shared_pools"
  ON public.shared_pools
  FOR SELECT
  TO anon
  USING (true);
