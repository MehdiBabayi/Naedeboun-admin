import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(JSON.stringify({ error: 'Missing SUPABASE envs' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const contentType = req.headers.get('content-type') ?? '';
    if (!contentType.includes('multipart/form-data')) {
      return new Response(JSON.stringify({ error: 'Content-Type must be multipart/form-data' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const formData = await req.formData();
    const file = formData.get('file');
    const type = String(formData.get('type') || 'note'); // 'note' | 'exercise'
    const lessonId = String(formData.get('lesson_id') || 'unknown');
    const videoId = String(formData.get('video_id') || 'unknown');

    if (!(file instanceof File)) {
      return new Response(JSON.stringify({ error: 'file is required' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const ext = (file.name.split('.').pop() || 'pdf').toLowerCase();
    const folder = type === 'exercise' ? 'exercises' : 'notes';
    const objectPath = `pdfs/${folder}/${lessonId}/${videoId}/${Date.now()}.${ext}`;

    const { data, error } = await supabase.storage.from('pdfs').upload(objectPath, await file.arrayBuffer(), {
      contentType: file.type || 'application/pdf',
      upsert: true,
    });
    if (error) throw error;

    // If bucket is public, build public URL
    const publicUrl = `${supabaseUrl}/storage/v1/object/public/${objectPath}`;

    return new Response(JSON.stringify({ path: objectPath, publicUrl }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (e) {
    console.error('upload-pdf error', e);
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});


