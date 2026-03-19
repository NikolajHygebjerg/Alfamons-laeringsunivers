-- Fix: Gør trigger idempotent så duplicate key ikke fejler ved dobbelt-klik/race
CREATE OR REPLACE FUNCTION create_match_on_accept()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' THEN
    INSERT INTO kid_matches (invitation_id, kid1_id, kid2_id)
    VALUES (NEW.id, NEW.challenger_kid_id, NEW.challenged_kid_id)
    ON CONFLICT (invitation_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
