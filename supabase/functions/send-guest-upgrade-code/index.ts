import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { corsHeaders } from "../_shared/cors.ts";
import { requireCurrentUser } from "../_shared/auth_user.ts";
import {
  ensureMailEnv,
  generateCode,
  json,
  normalizeEmail,
  supabase,
  upsertVerificationCode,
  verificationPurpose,
} from "../_shared/verification_code.ts";

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json(405, { code: "method_not_allowed", message: "仅支持 POST 请求" });
  }

  const envError = await ensureMailEnv();
  if (envError != null) {
    return envError;
  }

  try {
    const authResult = await requireCurrentUser(request.headers.get("Authorization"));
    if (authResult.response != null) {
      return authResult.response;
    }

    const currentUser = authResult.user;
    if (!currentUser?.is_anonymous) {
      return json(403, {
        code: "guest_upgrade_only",
        message: "当前账号不是游客账号，无法发送升级验证码。",
      });
    }

    const { email } = await request.json();
    const normalizedEmail = typeof email == "string" ? normalizeEmail(email) : "";
    if (!normalizedEmail) {
      return json(400, { code: "invalid_email", message: "请输入正确邮箱。" });
    }

    const currentEmail = currentUser.email?.trim().toLowerCase();
    if (currentEmail == normalizedEmail) {
      return json(400, {
        code: "email_already_bound",
        message: "该邮箱已绑定当前账号，请直接输入验证码完成升级。",
      });
    }

    const { data: emailRegistered, error: emailRegisteredError } = await supabase
      .rpc("is_auth_email_registered", { target_email: normalizedEmail });

    if (emailRegisteredError) {
      throw emailRegisteredError;
    }

    if (emailRegistered === true) {
      return json(409, {
        code: "email_already_registered",
        message: "该邮箱已注册，请直接登录。",
      });
    }

    const code = generateCode();
    const result = await upsertVerificationCode({
      email: normalizedEmail,
      code,
      purpose: verificationPurpose.guestUpgrade,
    });
    if (!result.ok) {
      return result.response!;
    }

    return json(200, { success: true, message: "验证码已发送，请检查邮箱。" });
  } catch (error) {
    console.error("send-guest-upgrade-code failed", error);
    return json(500, {
      code: "unexpected_failure",
      message: "发送升级验证码失败，请稍后重试。",
    });
  }
});
