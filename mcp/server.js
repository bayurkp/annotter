#!/usr/bin/env node

/**
 * Annotter MCP Server & HTTP Bridge
 *
 * - Runs a lightweight HTTP server on port 1357 for Flutter to sync annotations.
 * - Connects via MCP STDIO JSON-RPC to Cursor, Claude Code, and Antigravity.
 * - Zero frameworks, native Node.js HTTP + @modelcontextprotocol/sdk.
 */

import http from "http";
import fs from "fs";
import path from "path";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const HTTP_PORT = process.env.ANNOTTER_PORT
  ? parseInt(process.env.ANNOTTER_PORT, 10)
  : 1357;

// In-memory store of active annotations
const annotations = new Map();

function log(msg) {
  process.stderr.write(`[annotter-mcp] ${msg}\n`);
}

// -----------------------------------------------------------------------------
// 1. HTTP Server for Flutter Client
// -----------------------------------------------------------------------------
const httpServer = http.createServer((req, res) => {
  // Enable CORS
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://localhost:${HTTP_PORT}`);
  const pathname = url.pathname;

  // GET /api/ping (Health / Connection check)
  if (
    req.method === "GET" &&
    (pathname === "/api/ping" || pathname === "/ping")
  ) {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        status: "ok",
        pong: true,
        server: "annotter-mcp",
        version: "0.2.0",
        activeAnnotations: annotations.size,
      }),
    );
    return;
  }

  // GET /api/annotations
  if (req.method === "GET" && pathname === "/api/annotations") {
    const list = Array.from(annotations.values());
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(list));
    return;
  }

  // POST /api/annotations
  if (req.method === "POST" && pathname === "/api/annotations") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        const shouldReplace = url.searchParams.get("replace") === "true";
        if (shouldReplace) {
          annotations.clear();
          log("Cleared previous annotations (replace mode active)");
        }

        const data = JSON.parse(body);
        if (Array.isArray(data)) {
          for (const item of data) {
            if (item && item.id) {
              annotations.set(item.id, item);
            }
          }
          log(
            `Batch synced ${data.length} annotations (replace: ${shouldReplace})`,
          );
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(
            JSON.stringify({
              success: true,
              count: data.length,
              replaced: shouldReplace,
            }),
          );
          return;
        }

        const item = data;
        if (!item.id) {
          res.writeHead(400, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: "Missing item id" }));
          return;
        }
        annotations.set(item.id, item);
        log(
          `Synced annotation #${item.number || item.id}: [${item.widgetName}] - ${item.note || ""}`,
        );
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ success: true, item }));
      } catch (err) {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  // POST /api/upload-screenshot (Direct screenshot upload from Android / iOS / Web / Desktop)
  if (req.method === "POST" && pathname === "/api/upload-screenshot") {
    const filename = url.searchParams.get("filename") || `annotter_${Date.now()}.png`;
    const safeFilename = path.basename(filename);
    const screenshotsDir = path.resolve(process.cwd(), ".annotter", "screenshots");

    try {
      if (!fs.existsSync(screenshotsDir)) {
        fs.mkdirSync(screenshotsDir, { recursive: true });
      }
    } catch (err) {
      log(`Failed to create screenshots dir: ${err.message}`);
    }

    const targetFilePath = path.join(screenshotsDir, safeFilename);
    const chunks = [];

    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      try {
        const buffer = Buffer.concat(chunks);
        fs.writeFileSync(targetFilePath, buffer);
        log(`Saved uploaded screenshot: ${targetFilePath} (${buffer.length} bytes)`);

        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(
          JSON.stringify({
            success: true,
            filename: safeFilename,
            localPath: targetFilePath,
            size: buffer.length,
          }),
        );
      } catch (err) {
        log(`Failed saving uploaded screenshot: ${err.message}`);
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  // DELETE /api/annotations/:id
  if (req.method === "DELETE" && pathname.startsWith("/api/annotations/")) {
    const id = pathname.replace("/api/annotations/", "");
    if (annotations.has(id)) {
      annotations.delete(id);
      log(`Deleted annotation: ${id}`);
    }
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ success: true }));
    return;
  }

  // DELETE /api/annotations (Clear all)
  if (req.method === "DELETE" && pathname === "/api/annotations") {
    annotations.clear();
    log("Cleared all annotations");
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ success: true }));
    return;
  }

  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Not found" }));
});

httpServer.listen(HTTP_PORT, () => {
  log(`HTTP Bridge listening on http://localhost:${HTTP_PORT}`);
});

// -----------------------------------------------------------------------------
// 2. MCP Server (STDIO for Cursor, Claude Code, etc.)
// -----------------------------------------------------------------------------
const mcpServer = new Server(
  {
    name: "annotter-mcp",
    version: "0.2.0",
  },
  {
    capabilities: {
      tools: {},
    },
  },
);

mcpServer.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "annotter_get_pending_annotations",
        description:
          "Get all pending UI feedback and annotations submitted by the user from the running Flutter app.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "annotter_resolve_annotation",
        description:
          "Mark an annotation as resolved once you have fixed the code. This turns the marker on the user's Flutter screen into a green checkmark.",
        inputSchema: {
          type: "object",
          properties: {
            id: {
              type: "string",
              description:
                "The ID of the annotation to resolve (e.g., 'ann_1788489123' or '1')",
            },
            message: {
              type: "string",
              description: "Brief summary of what was changed or fixed",
            },
          },
          required: ["id"],
        },
      },
      {
        name: "annotter_clear_all",
        description: "Clear all annotations from the current session.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
    ],
  };
});

mcpServer.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name === "annotter_get_pending_annotations") {
    const pending = Array.from(annotations.values()).filter(
      (a) => a.status !== "resolved",
    );
    if (pending.length === 0) {
      return {
        content: [
          {
            type: "text",
            text: "No pending annotations found. All clear!",
          },
        ],
      };
    }

    const formatted = pending
      .map((item) => {
        const tags = [item.mode?.toUpperCase() || "WIDGET"];
        if (item.intent) tags.push(item.intent.toUpperCase());
        if (item.severity) tags.push(item.severity.toUpperCase());

        let out = `### #${item.number || 1} [${tags.join("][")}] ${item.widgetName}\n`;
        if (item.selectedText) out += `- Content: "${item.selectedText}"\n`;
        if (item.route) out += `- Screen/Route: ${item.route}\n`;
        if (item.screenshotPath)
          out += `- Snapshot: \`${item.screenshotPath}\`\n`;
        if (item.hierarchy && item.hierarchy.length > 0) {
          out += `- Tree: ${item.hierarchy.slice().reverse().join(" > ")}\n`;
        }
        out += `- Note: ${item.note || "No note provided"}\n`;
        out += `- ID: ${item.id}\n`;
        return out;
      })
      .join("\n---\n\n");

    return {
      content: [
        {
          type: "text",
          text: `Found ${pending.length} pending annotations from user:\n\n${formatted}`,
        },
      ],
    };
  }

  if (name === "annotter_resolve_annotation") {
    let id = String(args.id);
    if (!id.startsWith("ann_")) {
      id = `ann_${id}`;
    }

    let found = annotations.get(id);
    if (!found) {
      for (const [key, val] of annotations.entries()) {
        if (String(val.number) === String(args.id)) {
          found = val;
          id = key;
          break;
        }
      }
    }

    if (!found) {
      return {
        content: [
          {
            type: "text",
            text: `Annotation ${args.id} not found. Active IDs: ${Array.from(annotations.keys()).join(", ")}`,
          },
        ],
      };
    }

    found.status = "resolved";
    annotations.set(id, found);
    log(`Resolved annotation ${id}: ${args.message || "Done"}`);

    return {
      content: [
        {
          type: "text",
          text: `✓ Annotation #${found.number || id} marked as resolved! The screen pin has turned green. ${args.message ? `(${args.message})` : ""}`,
        },
      ],
    };
  }

  if (name === "annotter_clear_all") {
    annotations.clear();
    log("All annotations cleared via MCP");
    return {
      content: [
        {
          type: "text",
          text: "All annotations cleared successfully.",
        },
      ],
    };
  }

  throw new Error(`Unknown tool: ${name}`);
});

async function run() {
  const transport = new StdioServerTransport();
  await mcpServer.connect(transport);
  log("Annotter MCP STDIO server connected and ready for AI agents.");
}

run().catch((err) => {
  log(`Error starting MCP server: ${err.message}`);
  process.exit(1);
});
