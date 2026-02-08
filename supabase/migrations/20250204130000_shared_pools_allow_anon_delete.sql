-- Allow app (anon) to delete a shared_pools row by code (e.g. when owner removes the shared pool).
-- Required for SharedPoolsService.deletePool(code:) to succeed.
DROP POLICY IF EXISTS "Allow anon to delete shared_pools" ON public.shared_pools;
CREATE POLICY "Allow anon to delete shared_pools"
  ON public.shared_pools
  FOR DELETE
  TO anon
  USING (true);
