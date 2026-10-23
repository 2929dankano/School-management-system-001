import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed." });
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json(401, { error: "Sign in as Principal first." });
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return json(500, { error: "Server authentication is not configured." });
  const auth = createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData, error: authError } = await auth.auth.getUser(authorization.slice(7));
  if (authError || !authData.user) return json(401, { error: "Your session is invalid or expired." });
  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: caller, error: callerError } = await admin.from("profiles").select("id,role,school_id,is_active").eq("id", authData.user.id).maybeSingle();
  if (callerError || !caller || caller.role !== "principal" || !caller.is_active || !caller.school_id) return json(403, { error: "Only an active Principal linked to a school can invite teachers." });
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json(400, { error: "Invalid request body." }); }
  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  const fullName = typeof body.full_name === "string" ? body.full_name.trim() : "";
  if (email.length < 5 || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json(400, { error: "Enter a valid teacher email address." });
  if (fullName.length < 2 || fullName.length > 160) return json(400, { error: "Enter the teacher's full name." });
  const { data: existing } = await admin.from("profiles").select("id").eq("email", email).maybeSingle();
  if (existing) return json(409, { error: "A profile already uses this email address." });
  const staffNumber = "TCH-" + crypto.randomUUID().replaceAll("-", "").slice(0, 10).toUpperCase();
  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, { data: { full_name: fullName, invited_role: "teacher", school_id: caller.school_id } });
  if (inviteError || !invited.user) {
    const duplicate = /already|registered|exists/i.test(inviteError?.message ?? "");
    return json(duplicate ? 409 : 400, { error: duplicate ? "This email may already have an Auth account. Check Authentication → Users." : "Invitation could not be sent. Check Auth email configuration." });
  }
  const { error: profileError } = await admin.from("profiles").insert({ id: invited.user.id, school_id: caller.school_id, full_name: fullName, email, role: "teacher", is_active: true });
  if (profileError) {
    await admin.auth.admin.deleteUser(invited.user.id);
    return json(500, { error: "Could not create the teacher profile. No active teacher account was kept." });
  }
  const { error: teacherError } = await admin.from("teachers").insert({ school_id: caller.school_id, profile_id: invited.user.id, staff_number: staffNumber, employment_status: "active" });
  if (teacherError) {
    await admin.from("profiles").delete().eq("id", invited.user.id);
    await admin.auth.admin.deleteUser(invited.user.id);
    return json(500, { error: "Could not create the teacher record. The incomplete account was rolled back." });
  }
  return json(201, { success: true, message: "Teacher invitation sent and teacher record created.", teacher: { id: invited.user.id, full_name: fullName, email, staff_number: staffNumber, school_id: caller.school_id } });
});
