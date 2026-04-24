import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { corsHeaders } from "../_shared/cors.ts";
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
    const { email } = await request.json();
    const normalizedEmail = typeof email == "string" ? normalizeEmail(email) : "";

    if (!normalizedEmail) {
      return json(400, { code: "invalid_email", message: "请输入正确邮箱。" });
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
      purpose: verificationPurpose.signup,
    });
    if (!result.ok) {
      return result.response!;
    }

    return json(200, { success: true, message: "验证码已发送，请检查邮箱。" });
  } catch (error) {
    console.error("send-signup-code failed", error);
    return json(500, {
      code: "unexpected_failure",
      message: "验证码发送失败，请稍后重试。",
    });
  }
});
