-- Når modstanderen lukker spillet, vinder den der bliver
ALTER TABLE kid_matches
  ADD COLUMN IF NOT EXISTS winner text CHECK (winner IN ('kid1', 'kid2'));
