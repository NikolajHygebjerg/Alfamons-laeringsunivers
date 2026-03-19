-- Tillad opdatering af lydfiler (bruges af noise reduction service)
CREATE POLICY "Authenticated update book-audio" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'book-audio' AND auth.role() = 'authenticated'
  );
