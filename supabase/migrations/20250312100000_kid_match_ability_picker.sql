-- Tilføj ability_picker til kid_match_rounds: hvem vælger evne (starter/vinder sidste runde)
ALTER TABLE kid_match_rounds
ADD COLUMN IF NOT EXISTS ability_picker text CHECK (ability_picker IN ('kid1', 'kid2'));
