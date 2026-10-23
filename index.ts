import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed." });

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json(401, { error: "Sign in as Super Admin first." });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(500, { error: "Server authentication is not configured." });
  }

  const token = authorization.slice("Bearer ".length);
  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser(token);
  if (authError || !authData.user) return json(401, { error: "Your session is invalid or expired. Sign in again." });

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: caller, error: callerError } = await admin
    .from("profiles")
    .select("role, is_active")
    .eq("id", authData.user.id)
    .maybeSingle();
  if (callerError || !caller || caller.role !== "super_admin" || !caller.is_active) {
    return json(403, { error: "Only an active Super Admin can create a Principal account." });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Invalid request body." });
  }

  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  const fullName = typeof body.full_name === "string" ? body.full_name.trim() : "";
  const schoolId = typeof body.school_id === "string" ? body.school_id.trim() : "";
  if (email.length < 5 || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json(400, { error: "Enter a valid Principal email address." });
  }
  if (fullName.length < 2 || fullName.length > 160) return json(400, { error: "Enter the Principal's full name." });
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(schoolId)) {
    return json(400, { error: "Choose a valid school." });
  }

  const { data: school, error: schoolError } = await admin
    .from("schools").select("id, name, is_active").eq("id", schoolId).maybeSingle();
  if (schoolError || !school) return json(404, { error: "The selected school was not found." });
  if (!school.is_active) return json(409, { error: "This school is inactive. Activate it before adding a Principal." });

  const { data: existingProfile } = await admin.from("profiles").select("id").eq("email", email).maybeSingle();
  if (existingProfile) return json(409, { error: "A profile already uses this email address." });

  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
    data: { full_name: fullName, invited_role: "principal", school_id: schoolId },
    redirectTo: undefined,
  });
  if (inviteError || !invited.user) {
    const message = inviteError?.message ?? "Could not send the invitation.";
    const status = /already|registered|exists/i.test(message) ? 409 : 400;
    return json(status, { error: status === 409 ? "This email may already have an account. Check Authentication → Users." : "The invitation could not be sent. Check the Auth email configuration and try again." });
  }

  const { error: profileError } = await admin.from("profiles").insert({
    id: invited.user.id,
    school_id: schoolId,
    full_name: fullName,
    email,
    role: "principal",
    is_active: true,
  });
  if (profileError) {
    await admin.auth.admin.deleteUser(invited.user.id);
    return json(500, { error: "The account could not be linked to the school. No active Principal account was kept. Please try again." });
  }

  return json(201, {
    success: true,
    message: "Principal invitation sent and account linked to the selected school.",
    principal: { id: invited.user.id, full_name: fullName, email, school_id: schoolId, school_name: school.name },
  });
});
