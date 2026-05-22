import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { requireCurrentUser } from "../_shared/auth_user.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { ensureBaseEnv, json, supabase } from "../_shared/verification_code.ts";

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json(405, { code: "method_not_allowed", message: "仅支持 POST 请求" });
  }

  const envError = await ensureBaseEnv();
  if (envError != null) {
    return envError;
  }

  const { user, response } = await requireCurrentUser(
    request.headers.get("Authorization"),
  );
  if (response != null || user == null) {
    return response ?? json(401, {
      code: "auth_required",
      message: "请先登录后再操作。",
    });
  }

  try {
    const bucket = supabase.storage.from("user-avatars");
    const { data: files, error: listError } = await bucket.list(user.id, {
      limit: 1000,
      sortBy: { column: "name", order: "asc" },
    });

    if (listError != null) {
      throw listError;
    }

    const paths = (files ?? [])
      .filter((file) => (file.name ?? "").trim().length > 0)
      .map((file) => `${user.id}/${file.name}`);

    if (paths.isNotEmpty) {
      const { error: removeError } = await bucket.remove(paths);
      if (removeError != null) {
        throw removeError;
      }
    }

    const { error: cleanupError } = await supabase.rpc("delete_account_data", {
      target_user_id: user.id,
    });
    if (cleanupError != null) {
      throw cleanupError;
    }

    const { error: deleteUserError } = await supabase.auth.admin.deleteUser(
      user.id,
    );
    if (deleteUserError != null) {
      throw deleteUserError;
    }

    return json(200, {
      success: true,
      message: "账号已删除",
    });
  } catch (error) {
    console.error("delete-account failed", error);
    return json(500, {
      code: "account_delete_failed",
      message: "删除账号失败，请稍后重试。",
    });
  }
});
