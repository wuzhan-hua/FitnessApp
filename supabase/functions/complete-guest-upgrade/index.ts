import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { corsHeaders } from "../_shared/cors.ts";
import { requireCurrentUser } from "../_shared/auth_user.ts";
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
    const authResult = await requireCurrentUser(request.headers.get("Authorization"));
    if (authResult.response != null) {
      return authResult.response;
    }

    const currentUser = authResult.user;
    if (!currentUser?.is_anonymous) {
      return json(403, {
        code: "guest_upgrade_only",
        message: "当前账号不是游客账号，无法升级为邮箱账号。",
      });
    }

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

    const currentEmail = currentUser.email?.trim().toLowerCase();
    if (emailRegistered === true && currentEmail != normalizedEmail) {
      return json(409, {
        code: "email_already_registered",
        message: "该邮箱已注册，请直接登录。",
      });
    }

    const { data: codeRow, error: codeRowError } = await readVerificationCodeRow(
      normalizedEmail,
      verificationPurpose.guestUpgrade,
    );

    if (codeRowError) {
      throw codeRowError;
    }

    console.log(
      "complete-guest-upgrade verification context",
      JSON.stringify({
        normalizedEmail,
        foundCodeRow: codeRow != null,
        codePurpose: codeRow?.purpose ?? null,
        consumedAt: codeRow?.consumed_at ?? null,
        expiresAt: codeRow?.expires_at ?? null,
        currentUserId: currentUser.id,
        isAnonymous: currentUser.is_anonymous,
      }),
    );

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
    console.log(
      "complete-guest-upgrade hash compare",
      JSON.stringify({
        normalizedEmail,
        inputCodeHash,
        storedCodeHash: codeRow.code_hash,
        currentUserId: currentUser.id,
        isAnonymous: currentUser.is_anonymous,
      }),
    );
    if (inputCodeHash != codeRow.code_hash) {
      return json(400, {
        code: "invalid_code",
        message: "验证码无效，请重新输入。",
      });
    }

    const { data: updatedUser, error: updateUserError } = await supabase.auth.admin
      .updateUserById(currentUser.id, {
        email: normalizedEmail,
        password: rawPassword,
        email_confirm: true,
        user_metadata: currentUser.user_metadata ?? {},
      });

    if (updateUserError) {
      throw updateUserError;
    }

    const verifiedAt =
      updatedUser.user?.email_confirmed_at ??
      updatedUser.user?.updated_at ??
      new Date().toISOString();

    const { error: upsertPublicUserError } = await supabase
      .from("users")
      .upsert({
        user_id: currentUser.id,
        email: normalizedEmail,
        email_verified_at: verifiedAt,
        last_sign_in_at: updatedUser.user?.last_sign_in_at,
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
      message: "游客账号已升级为邮箱账号。",
    });
  } catch (error) {
    console.error("complete-guest-upgrade failed", error);
    return json(500, {
      code: "unexpected_failure",
      message: "游客升级失败，请稍后重试。",
    });
  }
});
