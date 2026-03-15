/**
 * Audio Noise Reduction Service
 *
 * Downloads audio from Supabase Storage, applies FFmpeg afftdn filter,
 * and uploads the processed file back (overwrites original).
 *
 * Deploy to Railway, Render, or Fly.io. Requires FFmpeg installed.
 *
 * Environment variables:
 *   SUPABASE_URL - Your Supabase project URL
 *   SUPABASE_SERVICE_ROLE_KEY - Service role key (for storage access)
 *   API_KEY - Secret key for authenticating requests (optional but recommended)
 *   PORT - Server port (default 3000)
 */

const http = require('http');
const { createClient } = require('@supabase/supabase-js');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const { promisify } = require('util');

const execAsync = promisify(exec);

const PORT = process.env.PORT || 3000;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const API_KEY = process.env.API_KEY;

const BUCKET = 'book-audio';

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch {
        reject(new Error('Invalid JSON'));
      }
    });
    req.on('error', reject);
  });
}

function authOk(req) {
  if (!API_KEY) return true;
  const auth = req.headers['authorization'] || req.headers['x-api-key'];
  return auth === `Bearer ${API_KEY}` || auth === API_KEY;
}

async function processAudio(filePath) {
  const tmpDir = path.dirname(filePath);
  const outputPath = path.join(tmpDir, `denoised_${path.basename(filePath)}`);
  // afftdn: nr=12 (noise reduction dB), nf=-50 (noise floor), tn=1 (track noise adaptively)
  const cmd = `ffmpeg -y -i "${filePath}" -af "afftdn=nr=12:nf=-50:tn=1" "${outputPath}"`;
  await execAsync(cmd);
  return outputPath;
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json');

  if (req.method !== 'POST' || req.url !== '/process') {
    res.writeHead(404);
    res.end(JSON.stringify({ error: 'Not found' }));
    return;
  }

  if (!authOk(req)) {
    res.writeHead(401);
    res.end(JSON.stringify({ error: 'Unauthorized' }));
    return;
  }

  let body;
  try {
    body = await parseBody(req);
  } catch {
    res.writeHead(400);
    res.end(JSON.stringify({ error: 'Invalid JSON body' }));
    return;
  }

  const { path: filePath } = body;
  if (!filePath || typeof filePath !== 'string') {
    res.writeHead(400);
    res.end(JSON.stringify({ error: 'Missing "path" in body' }));
    return;
  }

  // Sanitize: only allow filename, no path traversal
  const safePath = path.basename(filePath);
  if (!safePath || safePath.includes('..')) {
    res.writeHead(400);
    res.end(JSON.stringify({ error: 'Invalid path' }));
    return;
  }

  const tmpDir = path.join(process.cwd(), 'tmp');
  const inputPath = path.join(tmpDir, safePath);

  try {
    fs.mkdirSync(tmpDir, { recursive: true });

    // Download from Supabase Storage
    const { data, error: downloadError } = await supabase.storage
      .from(BUCKET)
      .download(safePath);

    if (downloadError || !data) {
      res.writeHead(404);
      res.end(JSON.stringify({ error: 'File not found in storage', detail: downloadError?.message }));
      return;
    }

    const buffer = Buffer.from(await data.arrayBuffer());
    fs.writeFileSync(inputPath, buffer);

    // Process with FFmpeg
    const outputPath = await processAudio(inputPath);
    const processedBuffer = fs.readFileSync(outputPath);

    // Upload back (overwrite)
    const { error: uploadError } = await supabase.storage
      .from(BUCKET)
      .upload(safePath, processedBuffer, { upsert: true });

    // Cleanup
    try {
      fs.unlinkSync(inputPath);
      fs.unlinkSync(outputPath);
    } catch {}

    if (uploadError) {
      res.writeHead(500);
      res.end(JSON.stringify({ error: 'Upload failed', detail: uploadError.message }));
      return;
    }

    res.writeHead(200);
    res.end(JSON.stringify({ success: true, path: safePath }));
  } catch (err) {
    console.error(err);
    try {
      if (fs.existsSync(inputPath)) fs.unlinkSync(inputPath);
      const outPath = path.join(tmpDir, `denoised_${safePath}`);
      if (fs.existsSync(outPath)) fs.unlinkSync(outPath);
    } catch {}
    res.writeHead(500);
    res.end(JSON.stringify({ error: 'Processing failed', detail: err.message }));
  }
});

server.listen(PORT, () => {
  console.log(`Noise reduction service listening on port ${PORT}`);
});
