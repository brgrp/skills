---
name: azure-foundry-search
description: |
  Real-time web search using Azure AI Foundry's Responses API with Grounding with Bing.
  USE FOR: Current events, recent news, latest prices, weather, stock quotes, recent releases, 
  verifying current facts, "what's the latest on X", any information that may have changed recently.
  DO NOT USE FOR: Historical facts, timeless knowledge, code documentation, internal data queries.
metadata:
  version: "2.3.0"
---

# Azure AI Foundry Search

Search the web for current information using Azure AI Foundry's Responses API with Grounding with Bing.

## Agent Workflow

1. **Check configuration** before first use:
   ```bash
   ./azure-foundry-search/scripts/foundry-search.sh status
   ```
   
   If not configured, run:
   ```bash
   ./azure-foundry-search/scripts/foundry-search.sh configure
   ```

2. **Run web searches** with the search command:
   ```bash
   ./azure-foundry-search/scripts/foundry-search.sh search "your question here"
   ```

3. **Parse the JSON response**:
   - `status: "success"` - use the `answer` field, cite sources from `citations`
   - `status: "error"` - check `error` and `code` fields, follow `solution`
   - `status: "no_results"` - try rephrasing

4. **Always cite sources** when presenting web search results to users.

## Quick Start

```bash
# First-time setup (interactive)
./azure-foundry-search/scripts/foundry-search.sh configure

# Check configuration
./azure-foundry-search/scripts/foundry-search.sh status

# Search the web
./azure-foundry-search/scripts/foundry-search.sh search "latest technology news"
```

## Commands

### Configure (First-Time Setup)

```bash
# Interactive setup - prompts for endpoint, API key, and model
./azure-foundry-search/scripts/foundry-search.sh configure
```

This saves credentials securely to `~/.config/azure-foundry-search/config.json` with restricted permissions.

### Search

```bash
# Basic web search
./azure-foundry-search/scripts/foundry-search.sh search "your query"

# With regional context (localizes results)
./azure-foundry-search/scripts/foundry-search.sh search "local news" --country US

# High context (more detailed search)
./azure-foundry-search/scripts/foundry-search.sh search "explain topic" --context high

# Low context (faster, less detailed)
./azure-foundry-search/scripts/foundry-search.sh search "current date" --context low

# Text-only output (no JSON wrapper)
./azure-foundry-search/scripts/foundry-search.sh search "weather" --text-only

# Citations only
./azure-foundry-search/scripts/foundry-search.sh search "news" --citations

# Use specific model deployment
./azure-foundry-search/scripts/foundry-search.sh search "analysis" --model gpt-4o
```

### Status & Configuration

```bash
# Check configuration and test API connection
./azure-foundry-search/scripts/foundry-search.sh status

# Show current configuration (API key is masked)
./azure-foundry-search/scripts/foundry-search.sh show
```

## Output Format

**Success response:**
```json
{
  "status": "success",
  "query": "latest news",
  "answer": "Here are the latest developments...",
  "citations": [
    {"title": "Article Title", "url": "https://example.com/article"}
  ],
  "search_queries": ["news today", "latest developments"],
  "usage": {"input_tokens": 1000, "output_tokens": 500}
}
```

**Error response:**
```json
{
  "status": "error",
  "query": "your query",
  "error": "Error description",
  "code": "AUTH_ERROR",
  "solution": "Run: ./foundry-search.sh configure"
}
```

## Options

| Option | Description | Values |
|--------|-------------|--------|
| `--country` | Localize results to country | ISO 3166-1 alpha-2 (US, DE, GB, FR, etc.) |
| `--context` | Control search depth | low, medium (default), high |
| `--text-only` | Output only the answer text | - |
| `--citations` | Output only citations as JSON | - |
| `--model` | Override configured model | Model deployment name |

## Error Codes

All errors return JSON with `status`, `code`, `error`, and `solution` fields.

| Code | Description | Solution |
|------|-------------|----------|
| `CONFIG_ERROR` | Missing configuration | Run `./foundry-search.sh configure` |
| `AUTH_ERROR` | Invalid API key | Run `./foundry-search.sh configure` |
| `ACCESS_DENIED` | No permission | Check Azure RBAC permissions |
| `NOT_FOUND` | Model/API not found | Verify model deployment name |
| `RATE_LIMITED` | Too many requests | Wait `retry_after` seconds and retry |
| `CONNECTION_ERROR` | Cannot reach endpoint | Check network and endpoint URL |
| `MISSING_QUERY` | No search query provided | Provide a query string |
| `INVALID_OPTION` | Unknown command-line option | Check available options with `help` |
| `INVALID_COUNTRY` | Bad country code | Use 2-letter ISO code (US, DE, GB) |
| `INVALID_CONTEXT` | Bad context size | Use: low, medium, or high |
| `INVALID_ENDPOINT` | Endpoint not HTTPS | Use https:// URL for the endpoint |
| `INVALID_MODEL` | Bad model name format | Use alphanumeric, dots, underscores, hyphens only |
| `DEPENDENCY_ERROR` | Missing curl or jq | Install the missing commands |
| `API_ERROR` | General API error | Check error message and http_code |

## Setup

### Prerequisites

- `curl` and `jq` installed (standard on most systems)
- Azure AI Services resource with a model deployment
- API key from Azure Portal

### First-Time Setup

Run the configure command:

```bash
./azure-foundry-search/scripts/foundry-search.sh configure
```

You'll be prompted for:
1. **Endpoint**: Your Azure AI Services endpoint (e.g., `https://<resource>.services.ai.azure.com`)
2. **API Key**: From Azure Portal > AI Services > Keys and Endpoint
3. **Model**: Your deployed model name (e.g., `gpt-4o`, `gpt-5-mini`)

### Getting Your API Key

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your Azure AI Services resource
3. Go to **Resource Management** > **Keys and Endpoint**
4. Copy **Key 1** or **Key 2**

### Finding Your Endpoint

1. In the same Azure AI Services resource
2. Look for **Endpoint** in the overview
3. Use the `.services.ai.azure.com` endpoint (not `.openai.azure.com`)

### Verify Setup

```bash
./azure-foundry-search/scripts/foundry-search.sh status
```

Expected output:
```
[INFO] Endpoint: https://<your-resource>.services.ai.azure.com
[INFO] API Key: abc1...xyz9
[INFO] Model: gpt-5-mini
[INFO] Testing API connection...
[INFO] API connection successful
[INFO] Web search is available
{"status":"ok","configured":true,...}
```

## Configuration

### Config File Location

```
~/.config/azure-foundry-search/config.json
```

### Configuration Priority

1. **Environment variables** (if set, always take priority)
2. **Config file** (default)

### Environment Variables (Optional)

You can override the config file using environment variables:

```bash
export AZURE_FOUNDRY_ENDPOINT="https://<resource>.services.ai.azure.com"
export AZURE_FOUNDRY_API_KEY="your-api-key"
export AZURE_FOUNDRY_MODEL="gpt-5-mini"
```

## Security

- Credentials stored in `~/.config/azure-foundry-search/` (owner-only access)
- API key masked in `show` output
- Web search uses Grounding with Bing - review [Microsoft's terms](https://www.microsoft.com/en-us/bing/apis/grounding-with-bing-terms)

## Notes

- Web search returns **real-time results** from the public web
- Results include **inline citations** - always cite sources when presenting to users
- Usage incurs costs - see [Azure AI Foundry pricing](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/)
- The model may execute multiple search queries to answer complex questions
- High context searches take longer but provide more comprehensive results
