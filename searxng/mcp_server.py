#!/usr/bin/env python3
import os
import requests
from mcp.server.fastmcp import FastMCP

SEARXNG_URL = os.environ.get("SEARXNG_URL", "http://localhost:8080")
TRANSPORT = os.environ.get("MCP_TRANSPORT", "stdio")
HOST = os.environ.get("MCP_HOST", "0.0.0.0")
PORT = int(os.environ.get("MCP_PORT", "8001"))

mcp = FastMCP("searxng", host=HOST, port=PORT)

@mcp.tool()
def web_search(query: str, num_results: int = 10) -> str:
    """Search the web using SearXNG. Returns titles, URLs and snippets."""
    try:
        resp = requests.get(
            f"{SEARXNG_URL}/search",
            params={"q": query, "format": "json", "pageno": 1},
            timeout=15,
        )
        resp.raise_for_status()
        data = resp.json()
        results = data.get("results", [])[:num_results]
        if not results:
            return "Keine Ergebnisse gefunden."
        lines = []
        for i, r in enumerate(results, 1):
            lines.append(f"{i}. {r.get('title', 'Kein Titel')}")
            lines.append(f"   URL: {r.get('url', '')}")
            if r.get("content"):
                lines.append(f"   {r['content'][:200]}")
            lines.append("")
        return "\n".join(lines)
    except Exception as e:
        return f"Fehler bei der Suche: {e}"

if __name__ == "__main__":
    if TRANSPORT in ("sse", "streamable-http"):
        mcp.run(transport=TRANSPORT)
    else:
        mcp.run()
