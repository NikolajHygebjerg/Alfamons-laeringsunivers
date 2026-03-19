// Supabase Edge Function: Proxy til noise reduction service
// Kalder den eksterne FFmpeg-service med den uploadede filsti.
//
// Secrets (supabase secrets set):
//   NOISE_REDUCTION_SERVICE_URL - fx. https://xxx.railway.app
//   NOISE_REDUCTION_API_KEY - samme som API_KEY i noise reduction service

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Manglende autorisation" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Ugyldig eller udløbet session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json().catch(() => ({}));
    const path = body?.path;
    if (!path || typeof path !== "string") {
      return new Response(
        JSON.stringify({ error: 'Manglende "path" i body' }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const serviceUrl = Deno.env.get("NOISE_REDUCTION_SERVICE_URL");
    const apiKey = Deno.env.get("NOISE_REDUCTION_API_KEY");

    if (!serviceUrl) {
      return new Response(
        JSON.stringify({ error: "Noise reduction service er ikke konfigureret" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const url = `${serviceUrl.replace(/\/$/, "")}/process`;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 60000);

    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(apiKey && { Authorization: `Bearer ${apiKey}` }),
      },
      body: JSON.stringify({ path }),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);
    const data = await res.json().catch(() => ({}));

    return new Response(JSON.stringify(data), {
      status: res.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const msg = err instanceof Error && err.name === "AbortError"
      ? "Timeout"
      : String(err);
    return new Response(
      JSON.stringify({ error: "Serverfejl", detail: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
