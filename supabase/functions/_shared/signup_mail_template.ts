export function buildSignupMailTemplate(code: string, scene: string) {
  return `
<!DOCTYPE html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>ForgeLog 邮箱验证码</title>
  </head>
  <body style="margin:0;padding:0;background:#f5f7fb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#14213d;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f5f7fb;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:20px;padding:32px;border:1px solid #d9e2f1;">
            <tr>
              <td>
                <div style="font-size:28px;font-weight:800;letter-spacing:0.4px;">ForgeLog</div>
                <div style="margin-top:8px;font-size:14px;line-height:1.7;color:#52607a;">
                  你正在${scene}。请输入下面的 6 位验证码完成验证。
                </div>
                <div style="margin-top:28px;padding:18px 20px;background:#eef3ff;border-radius:16px;text-align:center;">
                  <div style="font-size:13px;color:#52607a;">邮箱验证码</div>
                  <div style="margin-top:10px;font-size:32px;letter-spacing:10px;font-weight:800;color:#0f172a;">${code}</div>
                </div>
                <div style="margin-top:24px;font-size:14px;line-height:1.8;color:#52607a;">
                  验证码 10 分钟内有效。如果这不是你的操作，请忽略本邮件。
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
`;
}
