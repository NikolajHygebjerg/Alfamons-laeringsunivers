-- ============================================================
-- Tilføj kid_match tabeller til Supabase Realtime
-- ============================================================
--
-- Realtime konfigureres under DATABASE → PUBLICATIONS (ikke Replication!)
--
-- Metode 1 - Via Dashboard:
--   1. Gå til Supabase Dashboard
--   2. Database → Publications (https://supabase.com/dashboard/project/_/database/publications)
--   3. Klik på "supabase_realtime"
--   4. Toggle ON for: kid_match_invitations, kid_matches, kid_match_rounds
--
-- Metode 2 - Via SQL (kør i SQL Editor):
--   Kør dette script efter migrationen er kørt

ALTER PUBLICATION supabase_realtime ADD TABLE kid_match_invitations;
ALTER PUBLICATION supabase_realtime ADD TABLE kid_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE kid_match_rounds;
