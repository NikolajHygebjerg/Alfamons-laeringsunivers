# Audio Noise Reduction Service (Production)

Server-side støjreduktion for lydfiler i lydbiblioteket. Bruger FFmpeg's `afftdn`-filter.

## Endpoints

- `POST /process` – Process audio (kræver Authorization: Bearer API_KEY)
- `GET /health` – Health check for monitoring

## Deployment (Railway, Render, Fly.io)

### Environment variables

| Variable | Beskrivelse |
|----------|-------------|
| `SUPABASE_URL` | Din Supabase projekt-URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key fra Supabase Dashboard → Settings → API |
| `API_KEY` | Hemmelig nøgle til at sikre endpoint (vælg en lang tilfældig streng) |
| `PORT` | Serverport (standard 3000) |

### Railway

1. Opret projekt på [railway.app](https://railway.app)
2. "Deploy from GitHub" eller "Empty Project" + deploy fra mappe
3. Tilføj environment variables
4. Notér den genererede URL (fx. `https://xxx.railway.app`)

### Render

1. Opret Web Service på [render.com](https://render.com)
2. Connect til repo eller deploy fra mappe
3. Build command: `npm install`
4. Start command: `npm start`
5. Tilføj environment variables
6. Notér URL

### Fly.io

```bash
cd noise_reduction_service
fly launch
fly secrets set SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... API_KEY=...
fly deploy
```

## Lokal test

```bash
cd noise_reduction_service
npm install
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... API_KEY=test123 node index.js
```

Test:
```bash
curl -X POST http://localhost:3000/process \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test123" \
  -d '{"path":"hund_1234567890.wav"}'
```
