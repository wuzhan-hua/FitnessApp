import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

import { json, supabaseUrl } from "./verification_code.ts";

const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

export async function requireCurrentUser(
  authorizationHeader: string | null,
) {
  if (!supabaseUrl || !anonKey) {
    return {
      user: null,
      response: json(500, {
        code: "missing_env",
        message: "服务端环境变量未配置完整，请检查 Edge Function Secrets。",
      }),
    };
  }

  const token = authorizationHeader?.replace(/^Bearer\s+/i, "").trim() ?? "";
  if (!token) {
    return {
      user: null,
      response: json(401, {
        code: "auth_required",
        message: "请先登录后再操作。",
      }),
    };
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data, error } = await authClient.auth.getUser(token);
  if (error || !data.user) {
    return {
      user: null,
      response: json(401, {
        code: "auth_required",
        message: "登录状态已失效，请重新登录。",
      }),
    };
  }

  return { user: data.user, response: null };
}
