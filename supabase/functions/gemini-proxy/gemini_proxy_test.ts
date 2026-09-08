import { assertEquals } from "jsr:@std/assert@1";

import { createGeminiProxyHandler, storageObjectUrl } from "./index.ts";

const supabaseUrl = "https://project.supabase.co";
const userId = "11111111-1111-4111-8111-111111111111";

const env: Record<string, string> = {
  SUPABASE_URL: supabaseUrl,
  SUPABASE_ANON_KEY: "anon-key",
  GEMINI_API_KEY: "gemini-key",
};

function readEnv(name: string) {
  return env[name];
}

function geminiTextResponse(text: string) {
  return new Response(
    JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

function post(body: unknown, authorization = "Bearer token") {
  return new Request("https://edge/gemini-proxy", {
    method: "POST",
    headers: { Authorization: authorization, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

function handlerWith(
  fetchImplementation: (
    input: RequestInfo | URL,
    init?: RequestInit,
  ) => Promise<Response>,
  options: { authenticated?: boolean } = {},
) {
  return createGeminiProxyHandler({
    readEnv,
    fetch: fetchImplementation,
    authenticate: async () =>
      (options.authenticated ?? true) ? { id: userId } : null,
  });
}

Deno.test("OPTIONS is answered without touching the provider", async () => {
  let called = false;
  const handler = handlerWith(async () => {
    called = true;
    return new Response(null);
  });

  const response = await handler(
    new Request("https://edge/gemini-proxy", { method: "OPTIONS" }),
  );

  assertEquals(response.status, 204);
  assertEquals(called, false);
});

Deno.test("an unauthenticated caller never reaches Gemini", async () => {
  let called = false;
  const handler = handlerWith(async () => {
    called = true;
    return geminiTextResponse("nope");
  }, { authenticated: false });

  const response = await handler(post({ action: "daily_advice", mood: "calm" }));

  assertEquals(response.status, 401);
  assertEquals(called, false);
});

Deno.test("an unknown action is rejected before any provider call", async () => {
  let called = false;
  const handler = handlerWith(async () => {
    called = true;
    return geminiTextResponse("nope");
  });

  const response = await handler(post({ action: "summarise_everything" }));

  assertEquals(response.status, 400);
  assertEquals(called, false);
});

Deno.test("daily_advice sends the pinned model and returns the text", async () => {
  let requestedUrl = "";
  let sentBody: Record<string, unknown> = {};
  const handler = handlerWith(async (input, init) => {
    requestedUrl = String(input);
    sentBody = JSON.parse(String(init?.body));
    return geminiTextResponse("  Nice balance today.  ");
  });

  const response = await handler(
    post({
      action: "daily_advice",
      mood: "happy",
      steps: 8000,
      caloriesEaten: 1800,
      meals: [
        { name: "Ramen", mealType: "lunch", calories: 600, foodReview: "Rich" },
      ],
    }),
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), { advice: "Nice balance today." });
  assertEquals(requestedUrl.includes("gemini-3.6-flash:generateContent"), true);
  // The key travels server-side only, and the safety instruction is ours.
  assertEquals(requestedUrl.includes("key=gemini-key"), true);
  const instruction = JSON.stringify(sentBody.systemInstruction);
  assertEquals(instruction.includes("Never diagnose"), true);
  assertEquals(JSON.stringify(sentBody.contents).includes("Ramen"), true);
});

Deno.test("daily_advice rejects a malformed meal list", async () => {
  let called = false;
  const handler = handlerWith(async () => {
    called = true;
    return geminiTextResponse("nope");
  });

  const response = await handler(
    post({ action: "daily_advice", mood: "happy", meals: [{ name: "" }] }),
  );

  assertEquals(response.status, 400);
  assertEquals(called, false);
});

Deno.test("trip_summary uses the cheaper summary model", async () => {
  let requestedUrl = "";
  const handler = handlerWith(async (input) => {
    requestedUrl = String(input);
    return geminiTextResponse("A gentle few days.");
  });

  const response = await handler(
    post({
      action: "trip_summary",
      trip: { title: "Kyoto", startDate: "2026-04-01", endDate: "2026-04-04" },
      entries: [
        { createdAt: "2026-04-01T09:00:00Z", mood: "happy", title: "Arrived", body: "" },
      ],
    }),
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), { summary: "A gentle few days." });
  assertEquals(
    requestedUrl.includes("gemini-3.1-flash-lite:generateContent"),
    true,
  );
});

Deno.test("trip_summary rejects an empty entry list", async () => {
  const handler = handlerWith(async () => geminiTextResponse("nope"));

  const response = await handler(
    post({
      action: "trip_summary",
      trip: { title: "Kyoto", startDate: "a", endDate: "b" },
      entries: [],
    }),
  );

  assertEquals(response.status, 400);
});

Deno.test("food_detection fetches the caller's own photo and parses it", async () => {
  const imageUrl =
    `${supabaseUrl}/storage/v1/object/public/journal-photos/${userId}/trip-1/entry-1.jpg`;
  const fetched: string[] = [];
  const handler = handlerWith(async (input, init) => {
    const url = String(input);
    fetched.push(url);
    if (url === imageUrl) {
      return new Response(new Uint8Array([1, 2, 3]), { status: 200 });
    }
    // Fenced JSON, which the model does emit despite being told not to.
    assertEquals(String(init?.method), "POST");
    return geminiTextResponse('```json\n{"name":"Ramen","estimatedCalories":620}\n```');
  });

  const response = await handler(post({ action: "food_detection", imageUrl }));

  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    food: { name: "Ramen", estimatedCalories: 620 },
  });
  assertEquals(fetched[0], imageUrl);
});

Deno.test("food_detection returns a null food rather than an error when unparseable", async () => {
  const imageUrl =
    `${supabaseUrl}/storage/v1/object/public/journal-photos/${userId}/trip-1/a.jpg`;
  const handler = handlerWith(async (input) => {
    if (String(input) === imageUrl) {
      return new Response(new Uint8Array([1]), { status: 200 });
    }
    return geminiTextResponse("I think that's a sandwich?");
  });

  const response = await handler(post({ action: "food_detection", imageUrl }));

  assertEquals(response.status, 200);
  assertEquals(await response.json(), { food: null });
});

Deno.test("food_detection refuses another user's photo", async () => {
  const otherUser = "22222222-2222-4222-8222-222222222222";
  let called = false;
  const handler = handlerWith(async () => {
    called = true;
    return new Response(new Uint8Array([1]), { status: 200 });
  });

  const response = await handler(
    post({
      action: "food_detection",
      imageUrl:
        `${supabaseUrl}/storage/v1/object/public/journal-photos/${otherUser}/t/a.jpg`,
    }),
  );

  assertEquals(response.status, 400);
  assertEquals(called, false);
});

Deno.test("food_detection refuses a URL on another host (SSRF)", async () => {
  let called = false;
  const handler = handlerWith(async () => {
    called = true;
    return new Response("secret", { status: 200 });
  });

  const response = await handler(
    post({
      action: "food_detection",
      imageUrl:
        `https://evil.example/storage/v1/object/public/journal-photos/${userId}/t/a.jpg`,
    }),
  );

  assertEquals(response.status, 400);
  assertEquals(called, false);
});

Deno.test("a provider failure is reported as provider_error, not leaked", async () => {
  const handler = handlerWith(async () =>
    new Response("Gemini said: invalid api key gemini-key", { status: 403 })
  );

  const response = await handler(
    post({ action: "daily_advice", mood: "happy", meals: [] }),
  );

  assertEquals(response.status, 502);
  const body = await response.json();
  assertEquals(body.error.code, "provider_error");
  assertEquals(JSON.stringify(body).includes("gemini-key"), false);
});

Deno.test("storageObjectUrl guards traversal and empty segments", () => {
  const base = `${supabaseUrl}/storage/v1/object/public/journal-photos`;

  assertEquals(
    storageObjectUrl(`${base}/${userId}/trip/a.jpg`, supabaseUrl, userId),
    `${base}/${userId}/trip/a.jpg`,
  );
  assertEquals(storageObjectUrl(`${base}/${userId}`, supabaseUrl, userId), null);
  assertEquals(
    storageObjectUrl(`${base}/${userId}/../other/a.jpg`, supabaseUrl, userId),
    null,
  );
  assertEquals(
    storageObjectUrl(`${base}//trip/a.jpg`, supabaseUrl, userId),
    null,
  );
  assertEquals(
    storageObjectUrl(
      `${supabaseUrl}/storage/v1/object/public/trip-covers/${userId}/a.jpg`,
      supabaseUrl,
      userId,
    ),
    null,
  );
  assertEquals(storageObjectUrl("not a url", supabaseUrl, userId), null);
});
