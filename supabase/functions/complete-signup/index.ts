import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { corsHeaders } from "../_shared/cors.ts";
import {
  ensureBaseEnv,
  json,
  normalizeEmail,
  readVerificationCodeRow,
  sha256,
  supabase,
  verificationPurpose,
} from "../_shared/verification_code.ts";

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

  try {
    const { email, code, password } = await request.json();
    const normalizedEmail = typeof email == "string" ? normalizeEmail(email) : "";
    const rawCode = typeof code == "string" ? code.trim() : "";
    const rawPassword = typeof password == "string" ? password.trim() : "";

    if (!normalizedEmail) {
      return json(400, { code: "invalid_email", message: "请输入正确邮箱。" });
    }
    if (rawCode.length != 6) {
      return json(400, { code: "invalid_code", message: "请输入 6 位验证码。" });
    }
    if (rawPassword.length < 6) {
      return json(400, { code: "invalid_password", message: "密码至少 6 位。" });
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

    const { data: codeRow, error: codeRowError } = await readVerificationCodeRow(
      normalizedEmail,
      verificationPurpose.signup,
    );

    if (codeRowError) {
      throw codeRowError;
    }

    if (!codeRow) {
      return json(400, {
        code: "code_not_found",
        message: "请先发送验证码。",
      });
    }

    if (codeRow.consumed_at != null) {
      return json(400, {
        code: "code_already_used",
        message: "验证码已使用，请重新获取。",
      });
    }

    if (new Date(codeRow.expires_at as string).getTime() < Date.now()) {
      return json(400, {
        code: "code_expired",
        message: "验证码已过期，请重新获取。",
      });
    }

    const inputCodeHash = await sha256(`${normalizedEmail}:${rawCode}`);
    if (inputCodeHash != codeRow.code_hash) {
      return json(400, {
        code: "invalid_code",
        message: "验证码无效，请重新输入。",
      });
    }

    const { data: createdUser, error: createUserError } = await supabase.auth.admin
      .createUser({
        email: normalizedEmail,
        password: rawPassword,
        email_confirm: true,
      });

    if (createUserError) {
      throw createUserError;
    }

    const createdAt =
      createdUser.user?.email_confirmed_at ??
      createdUser.user?.created_at ??
      new Date().toISOString();

    const { error: upsertPublicUserError } = await supabase
      .from("users")
      .upsert({
        user_id: createdUser.user?.id,
        email: normalizedEmail,
        email_verified_at: createdAt,
        last_sign_in_at: null,
        user_type: 1,
      }, { onConflict: "user_id" });

    if (upsertPublicUserError) {
      throw upsertPublicUserError;
    }

    const { error: consumeCodeError } = await supabase
      .from("signup_verification_codes")
      .update({ consumed_at: new Date().toISOString() })
      .eq("id", codeRow.id as string);

    if (consumeCodeError) {
      throw consumeCodeError;
    }

    return json(200, {
      success: true,
      message: "注册成功",
    });
  } catch (error) {
    console.error("complete-signup failed", error);
    return json(500, {
      code: "unexpected_failure",
      message: "注册失败，请稍后重试。",
    });
  }
});
