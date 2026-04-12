import type { PagesFunction } from "@cloudflare/workers-types";

/** Pages / Workers 环境：在控制台配置 Secret，或本地 .dev.vars */
export interface Env {
  GITHUB_TOKEN: string;
}

const DEFAULT_OWNER = "LoosePrince";
const DEFAULT_REPO = "SocialFlow";
const DEFAULT_BRANCH = "main";

function encodeGithubPath(path: string): string {
  return path
    .split("/")
    .filter((s) => s.length > 0)
    .map((segment) => encodeURIComponent(segment))
    .join("/");
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  const chunkSize = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const sub = bytes.subarray(i, Math.min(i + chunkSize, bytes.length));
    binary += String.fromCharCode(...sub);
  }
  return btoa(binary);
}

function cdnUrls(owner: string, repo: string, branch: string, pathInRepo: string): {
  jsdelivr: string;
  jsdmirror: string;
} {
  const normalized = pathInRepo.split("/").filter(Boolean).join("/");
  return {
    jsdelivr: `https://cdn.jsdelivr.net/gh/${owner}/${repo}@${branch}/${normalized}`,
    jsdmirror: `https://cdn.jsdmirror.com/gh/${owner}/${repo}@${branch}/${normalized}`,
  };
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

export const onRequestOptions: PagesFunction<Env> = async () => {
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Max-Age": "86400",
    },
  });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  const token = String(env.GITHUB_TOKEN ?? "").trim();
  if (!token) {
    return jsonResponse(
      { ok: false, error: "server_misconfigured", hint: "在 Pages/Workers 环境配置 Secret GITHUB_TOKEN，或本地使用 .dev.vars" },
      503,
    );
  }

  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    return jsonResponse({ ok: false, error: "invalid_form_data" }, 400);
  }

  const owner = String(form.get("owner") ?? DEFAULT_OWNER).trim() || DEFAULT_OWNER;
  const repo = String(form.get("repo") ?? DEFAULT_REPO).trim() || DEFAULT_REPO;
  const branch = String(form.get("branch") ?? DEFAULT_BRANCH).trim() || DEFAULT_BRANCH;
  const pathInRepo = String(form.get("path") ?? "").trim();
  if (!pathInRepo) {
    return jsonResponse({ ok: false, error: "missing_path" }, 400);
  }
  if (pathInRepo.startsWith("/") || pathInRepo.includes("..")) {
    return jsonResponse({ ok: false, error: "invalid_path" }, 400);
  }

  const rawFile = form.get("file");
  if (rawFile === null || typeof rawFile === "string") {
    return jsonResponse({ ok: false, error: "missing_or_empty_file" }, 400);
  }
  const file = rawFile as File;
  if (!file.size) {
    return jsonResponse({ ok: false, error: "missing_or_empty_file" }, 400);
  }

  const message = String(form.get("message") ?? "Upload via cf-gh-cdn").trim() || "Upload via cf-gh-cdn";

  const apiBase = `https://api.github.com/repos/${owner}/${repo}/contents/${encodeGithubPath(pathInRepo)}`;
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    Authorization: `Bearer ${token}`,
    "User-Agent": "cf-gh-file-cdn-pages-function",
  };

  let existingSha: string | undefined;
  const getUrl = `${apiBase}?ref=${encodeURIComponent(branch)}`;
  const getRes = await fetch(getUrl, { headers });
  if (getRes.status === 200) {
    const meta = (await getRes.json()) as { sha?: string };
    if (typeof meta.sha === "string") {
      existingSha = meta.sha;
    }
  } else if (getRes.status !== 404) {
    const errText = await getRes.text();
    return jsonResponse(
      {
        ok: false,
        error: "github_get_failed",
        status: getRes.status,
        detail: errText.slice(0, 2000),
      },
      502,
    );
  }

  const content = arrayBufferToBase64(await file.arrayBuffer());
  const body: Record<string, string> = {
    message,
    content,
    branch,
  };
  if (existingSha) {
    body.sha = existingSha;
  }

  const putRes = await fetch(apiBase, {
    method: "PUT",
    headers: {
      ...headers,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const putText = await putRes.text();
  let putJson: unknown;
  try {
    putJson = JSON.parse(putText) as Record<string, unknown>;
  } catch {
    putJson = { raw: putText.slice(0, 2000) };
  }

  if (!putRes.ok) {
    return jsonResponse(
      {
        ok: false,
        error: "github_put_failed",
        status: putRes.status,
        detail: putJson,
      },
      502,
    );
  }

  const urls = cdnUrls(owner, repo, branch, pathInRepo);

  return jsonResponse({
    ok: true,
    owner,
    repo,
    branch,
    path: pathInRepo,
    urls,
    github: putJson,
  });
};
