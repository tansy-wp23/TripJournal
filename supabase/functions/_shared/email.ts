// Gmail SMTP email sending for verification codes.
// Manual Prerequisite B: SMTP_USERNAME / SMTP_PASSWORD Supabase secrets.
import { SMTPClient } from "https://deno.land/x/denomailer/mod.ts";

export interface SendCodeEmailInput {
  to: string;
  code: string;
  purpose: "deactivation" | "reactivation";
}

export async function sendCodeEmail({
  to,
  code,
  purpose,
}: SendCodeEmailInput): Promise<void> {
  const username = Deno.env.get("SMTP_USERNAME");
  const password = Deno.env.get("SMTP_PASSWORD");
  if (!username || !password) {
    throw new Error("SMTP_USERNAME / SMTP_PASSWORD secrets are not configured");
  }

  const subject =
    purpose === "deactivation"
      ? "Your TripJournal deactivation code"
      : "Your TripJournal reactivation code";
  const body =
    `Your TripJournal verification code is: ${code}\n\n` +
    `This code expires in 10 minutes. If you didn't request this, you can safely ignore this email.`;

  const client = new SMTPClient({
    connection: {
      hostname: "smtp.gmail.com",
      port: 465,
      tls: true,
      auth: { username, password },
    },
  });

  try {
    await client.send({
      from: `TripJournal <${username}>`,
      to,
      subject,
      content: body,
    });
  } finally {
    await client.close();
  }
}