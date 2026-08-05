-- Barns egne ord-optagelser: ét klip pr. (barn, ord); bruges i alle bøger for barnet
-- Ord gemmes som normaliseret små bogstaver (app-matching som audio_library)

CREATE TABLE IF NOT EXISTS public.kid_word_recordings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kid_id uuid NOT NULL REFERENCES public.kids (id) ON DELETE CASCADE,
  word text NOT NULL,
  audio_url text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT kid_word_recordings_kid_word_unique UNIQUE (kid_id, word)
);

CREATE INDEX IF NOT EXISTS idx_kid_word_recordings_kid_id ON public.kid_word_recordings (kid_id);

ALTER TABLE public.kid_word_recordings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "kid_word_recordings_all_own" ON public.kid_word_recordings;
CREATE POLICY "kid_word_recordings_all_own" ON public.kid_word_recordings
  FOR ALL
  USING (
    kid_id IN (
      SELECT k.id
      FROM public.kids k
      JOIN public.profiles p ON p.id = k.parent_id
      WHERE p.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    kid_id IN (
      SELECT k.id
      FROM public.kids k
      JOIN public.profiles p ON p.id = k.parent_id
      WHERE p.auth_user_id = auth.uid()
    )
  );

COMMENT ON TABLE public.kid_word_recordings IS
  'Barns egne læse-ord: samme (kid_id,word) i alle bøger; lyd ligger i book-audio bucket.';
