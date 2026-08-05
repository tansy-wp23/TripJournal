import { parse } from "jsr:@std/toml@1.0.11";

import {
  createPurgeHandler,
  type PurgeClaim,
  type PurgeGateway,
} from "./purge.ts";

const configUrl = new URL("../../config.toml", import.meta.url);

function assertEquals(actual: unknown, expected: unknown, message?: string) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(
      message ?? `Expected ${expectedJson}, received ${actualJson}`,
    );
  }
}

class EmptyGateway implements PurgeGateway {
  claimExpiredTrips(): Promise<PurgeClaim[]> {
    return Promise.resolve([]);
  }

  removeObjects(): Promise<void> {
    return Promise.resolve();
  }

  permanentlyDeleteTrip(): Promise<void> {
    return Promise.resolve();
  }
}

Deno.test("deployment disables platform JWT verification while the handler enforces x-cron-secret", async () => {
  const config = parse(await Deno.readTextFile(configUrl));
  const functionConfig = (
    config.functions as Record<string, Record<string, unknown>> | undefined
  )?.["purge-deleted-trips"];
  assertEquals(functionConfig?.verify_jwt, false);

  const handler = createPurgeHandler({
    readEnv: (name) =>
      ({
        PURGE_CRON_SECRET: "contract-secret",
        SUPABASE_URL: "https://tripjournal.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
      } as Record<string, string>)[name],
    clock: () => new Date("2026-09-04T02:15:00.000Z"),
    createGateway: () => new EmptyGateway(),
  });

  const response = await handler(
    new Request("https://edge.example.test/purge", {
      method: "POST",
      headers: { "x-cron-secret": "contract-secret" },
    }),
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    processed: 0,
    deleted: 0,
    failed: 0,
  });
});
