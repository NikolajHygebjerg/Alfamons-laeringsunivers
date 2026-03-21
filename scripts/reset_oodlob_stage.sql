-- Reset Oodlob til udviklingstrin 1
-- Kør i Supabase SQL Editor for at rette forkert udviklingstrin.

-- Find Oodlob-avatar(er) og sæt current_stage_index til 1 i kid_avatar_library
UPDATE kid_avatar_library kal
SET current_stage_index = 1
FROM avatars a
WHERE kal.avatar_id = a.id
  AND (LOWER(a.name) IN ('oodlob', 'oglah', 'oqlen', 'odiab') OR a.letter = 'o')
  AND kal.current_stage_index > 1;

-- points_current beholdes uændret (fx 2 point)
