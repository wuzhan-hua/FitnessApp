import nodemailer from "npm:nodemailer@6.10.1";

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

import { buildSignupMailTemplate } from "./signup_mail_template.ts";

export const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
export const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const smtpHost = Deno.env.get("SMTP_HOST") ?? "";
const smtpUser = Deno.env.get("SMTP_USER") ?? "";
const smtpPass = Deno.env.get("SMTP_PASS") ?? "";
const smtpFromEmail = Deno.env.get("SMTP_FROM_EMAIL") ?? smtpUser;
const smtpFromName = Deno.env.get("SMTP_FROM_NAME") ?? "ForgeLog";
const smtpPort = Number(Deno.env.get("SMTP_PORT") ?? "465");

export const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

export const verificationPurpose = {
  signup: "signup",
  guestUpgrade: "guest_upgrade",
} as const;

export type VerificationPurpose =
  typeof verificationPurpose[keyof typeof verificationPurpose];

export function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Content-Type": "application/json",
    },
  });
}

export function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

export function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

export async function sha256(value: string) {
  const buffer = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(buffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function buildMailContent(code: string, purpose: VerificationPurpose) {
  const scene = purpose === verificationPurpose.guestUpgrade
    ? "升级 ForgeLog 游客账号"
    : "注册 ForgeLog 邮箱账号";
  return buildSignupMailTemplate(code, scene);
}

export async function sendVerificationMail(
  to: string,
  code: string,
  purpose: VerificationPurpose,
) {
  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    auth: { user: smtpUser, pass: smtpPass },
  });

  await transporter.sendMail({
    from: `${smtpFromName} <${smtpFromEmail}>`,
    to,
    subject: "ForgeLog 邮箱验证码",
    html: buildMailContent(code, purpose),
  });
}

export async function ensureBaseEnv() {
  if (!supabaseUrl || !serviceRoleKey) {
    return json(500, {
      code: "missing_env",
      message: "服务端环境变量未配置完整，请检查 Edge Function Secrets。",
    });
  }
  return null;
}

export async function ensureMailEnv() {
  const baseEnvError = await ensureBaseEnv();
  if (baseEnvError != null) {
    return baseEnvError;
  }
  if (!smtpHost || !smtpUser || !smtpPass) {
    return json(500, {
      code: "missing_env",
      message: "服务端环境变量未配置完整，请检查 Edge Function Secrets。",
    });
  }
  return null;
}

export async function readVerificationCodeRow(
  email: string,
  purpose: VerificationPurpose,
) {
  return await supabase
    .from("signup_verification_codes")
    .select("id, code_hash, expires_at, consumed_at, created_at, last_sent_at, send_count")
    .ilike("email", email)
    .eq("purpose", purpose)
    .maybeSingle();
}

export async function upsertVerificationCode({
  email,
  code,
  purpose,
}: {
  email: string;
  code: string;
  purpose: VerificationPurpose;
}) {
  const { data: existingCodeRow, error: existingCodeRowError } =
    await readVerificationCodeRow(email, purpose);

  if (existingCodeRowError) {
    throw existingCodeRowError;
  }

  const now = new Date();
  if (existingCodeRow?.last_sent_at) {
    const lastSentAt = new Date(existingCodeRow.last_sent_at as string);
    if (now.getTime() - lastSentAt.getTime() < 60 * 1000) {
      return {
        ok: false,
        response: json(429, {
          code: "send_too_frequently",
          message: "验证码发送过于频繁，请 60 秒后再试。",
        }),
      };
    }
  }

  if (existingCodeRow?.created_at) {
    const windowStartedAt = new Date(existingCodeRow.created_at as string);
    if (
      now.getTime() - windowStartedAt.getTime() < 60 * 60 * 1000 &&
      Number(existingCodeRow.send_count ?? 0) >= 5
    ) {
      return {
        ok: false,
        response: json(429, {
          code: "send_hourly_limit_reached",
          message: "该邮箱当前发送次数已达上限，请稍后再试。",
        }),
      };
    }
  }

  const codeHash = await sha256(`${email}:${code}`);
  const expiresAt = new Date(now.getTime() + 10 * 60 * 1000).toISOString();
  const nextSendCount =
    existingCodeRow?.created_at &&
        now.getTime() - new Date(existingCodeRow.created_at as string).getTime() <
          60 * 60 * 1000
      ? Number(existingCodeRow.send_count ?? 0) + 1
      : 1;

  await sendVerificationMail(email, code, purpose);

  if (existingCodeRow?.id != null) {
    const { error: updateCodeError } = await supabase
      .from("signup_verification_codes")
      .update({
        email,
        purpose,
        code_hash: codeHash,
        expires_at: expiresAt,
        consumed_at: null,
        last_sent_at: now.toISOString(),
        send_count: nextSendCount,
        created_at:
          nextSendCount == 1 ? now.toISOString() : existingCodeRow.created_at,
      })
      .eq("id", existingCodeRow.id as string);
    if (updateCodeError) {
      throw updateCodeError;
    }
  } else {
    const { error: insertCodeError } = await supabase
      .from("signup_verification_codes")
      .insert({
        email,
        purpose,
        code_hash: codeHash,
        expires_at: expiresAt,
        last_sent_at: now.toISOString(),
        send_count: 1,
      });
    if (insertCodeError) {
      throw insertCodeError;
    }
  }

  return { ok: true, response: null };
}
