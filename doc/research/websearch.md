# Web Search MCPs Research Report

## Executive Summary

This report analyzes web search MCP (Model Context Protocol) servers available for AI agents, with focus on Codename Goose extensions and alternative solutions. The research covers functionality, accuracy, pricing, and practical usage patterns across major platforms.

## Codename Goose Web Search Extensions

### Overview
Codename Goose is an open-source, on-device AI agent from Block (formerly Square) that uses MCP as its plugin standard. Web search capabilities are provided through community and official MCP servers.

### Built-in Extensions
- **developer**: File I/O, shell commands, process spawning (default)
- **computercontroller**: Mouse/keyboard automation, screenshots
- **memory**: Persistent session memory (SQLite/LibSQL)
- **github**: PRs, issues, repo info (GitHub PAT required)
- **jetbrains**: IDE integration
- **google-drive, figma, slack**: Cloud service integrations

### Popular Web Search Extensions

| Extension | Install Command | Features | Pricing |
|-----------|----------------|----------|---------|
| **Brave Search** | `npx -y @modelcontextprotocol/server-brave-search` | Privacy-focused search, 2K queries/month free | Free tier + API key |
| **Tavily Search** | `npx -y mcp-tavily-search` | Research-grade search, academic focus | API key required |
| **Perplexity Search** | `npx -y mcp-perplexity-search` | AI-powered answers with citations | Premium API |
| **Jina AI Reader** | `npx -y mcp-jinaai-reader` | URL to Markdown conversion | Free tier |
| **Jina AI Grounding** | `npx -y mcp-jinaai-grounding` | Search + RAG grounding | Free tier |
| **SearXNG** | `uv run searxng-mcp` | Self-hosted/private search | Self-hosted |

### Configuration Example
```yaml
extensions:
  brave-search:
    name: brave-search
    type: stdio
    cmd: npx
    args: [-y, '@modelcontextprotocol/server-brave-search']
    envs: { BRAVE_API_KEY: 'YOUR_KEY' }
    enabled: true
  jinaai-reader:
    name: jinaai-reader
    type: stdio
    cmd: npx
    args: [-y, mcp-jinaai-reader]
    enabled: true
```

## Additional Web Search MCPs

### Performance Comparison (2024 Evaluation)

| Server | Accuracy | Speed | Key Strengths |
|--------|----------|-------|---------------|
| **Bing Web Search** | 64.33% | <15s | Highest accuracy, fast |
| **Fire Crawl Search** | 58.33% | 15.44s | Good balance |
| **Tavily MCP** | 47.99% | 95.52s | Research-focused |
| **Brave Search** | 46.6% | <15s | Privacy-focused, fast |
| **Qwen Web Search** | 55.52% | Varies | Function call based |
| **DuckDuckGo** | 13.62% | Varies | Privacy-focused, low accuracy |

### Premium Options
- **Perplexity Ask MCP**: LLM-powered search with citations
- **Bright Data MCP**: Enterprise-grade search + crawling
- **Google CSE MCP**: 100 queries/day free, then $5/1K queries

### Free/Open Source
- **Web Search MCP**: Google scraping, rate-limited
- **Open-WebSearch MCP**: Multi-engine support (Bing, DuckDuckGo, Brave, Baidu)

## Claude Built-in Web Search

### Capabilities
- Seamless integration with Claude's reasoning
- Automatic citation generation
- Geographic result localization
- Progressive multi-search for complex research
- Enterprise administrative controls

### Pricing
- **Search Cost**: $10 per 1,000 searches
- **Token Costs**: 
  - Claude 4 Sonnet: $3/$15 per million tokens (input/output)
  - Claude 4 Opus: $15/$75 per million tokens (input/output)

### Usage in Codex and Goose
Claude's web search can be integrated into other platforms through:
1. **API Integration**: Direct API calls with web search parameter
2. **MCP Bridge**: Custom MCP server wrapping Claude's web search
3. **Function Calling**: Using Claude's function calling capabilities

## Platform Comparison

| Platform | Type | Pricing | Best For |
|----------|------|---------|----------|
| **Goose + MCP Extensions** | Open source | Free (BYO API keys) | Maximum customization |
| **Claude Web Search** | Integrated | $10/1K searches + tokens | Seamless AI workflows |
| **Codex CLI** | Subscription | $5-50 API credits | OpenAI ecosystem |

### Performance Rankings (Terminal-Bench)
1. Warp (1st)
4. Goose (4th) 
19. Codex CLI (19th)

## Special Considerations for Existing Subscriptions

### Codex Teams Account Holders

**Existing Benefits:**
- **Higher API Credits**: Teams accounts typically include $50-200 in monthly API credits vs $5-50 for individual plans
- **Priority Access**: Reduced wait times during high-demand periods
- **Enhanced Rate Limits**: Higher request thresholds for enterprise workflows

**Web Search Integration Options:**
1. **Native Codex Integration**: Use built-in web search capabilities (limited compared to dedicated MCP servers)
2. **Hybrid Approach**: Combine Codex for coding tasks with Goose + MCP extensions for research
3. **Custom MCP Bridge**: Create internal MCP server that leverages Codex API for specific use cases

**Cost Analysis for Teams:**
- **Codex-only approach**: $0 additional cost (covered by existing subscription)
- **Goose + Premium MCPs**: ~$20-100/month depending on usage (API keys separate)
- **Recommendation**: Use Codex for development workflows, supplement with MCP servers for research-heavy tasks

### Perplexity Pro Subscribers

**Existing Benefits:**
- **300+ Searches/Day**: Significantly higher than free tiers
- **Advanced Models**: Access to GPT-4 and Claude models
- **File Upload**: PDF, text, and image analysis capabilities
- **API Access**: 100 free API calls/day, then $5/1K calls

**MCP Integration Strategies:**
1. **Perplexity MCP Server**: Direct integration using existing API key
2. **Hybrid Search Pipeline**: Perplexity for complex queries + Brave/Bing for bulk searches
3. **Research Workflows**: Leverage Perplexity's citation features for academic work

**Configuration Example:**
```yaml
extensions:
  perplexity-search:
    name: perplexity-search
    type: stdio
    cmd: npx
    args: [-y, mcp-perplexity-search]
    envs: { PERPLEXITY_API_KEY: 'YOUR_PRO_KEY' }
    enabled: true
```

**Cost Optimization:**
- **Perplexity Pro**: $20/month covers 300+ daily searches
- **MCP Integration**: 100 free API calls/day, then $5/1K
- **Recommendation**: Use Perplexity MCP for research tasks, supplement with free alternatives for bulk searches

### Hybrid Subscription Strategy

**For Users with Both Codex Teams + Perplexity Pro:**
1. **Development Tasks**: Codex CLI with native capabilities
2. **Research Tasks**: Goose + Perplexity MCP for high-quality results
3. **Bulk Operations**: Goose + Brave/Bing for cost-effective scaling
4. **File Processing**: Perplexity for PDF/document analysis

**Monthly Cost Breakdown:**
- **Existing Subscriptions**: $20 (Perplexity) + Teams plan (varies)
- **Additional MCP Costs**: $0-50 depending on usage
- **Total Additional**: Minimal beyond existing subscriptions

## Recommendations

### For Research Quality
1. **Bing Web Search MCP** - Highest accuracy (64.33%)
2. **Tavily MCP** - Research-grade with academic focus
3. **Perplexity MCP** - AI-enhanced with citations

### For Privacy
1. **Brave Search MCP** - Privacy-focused, good performance
2. **SearXNG** - Self-hosted, complete control
3. **DuckDuckGo MCP** - Privacy but lower accuracy

### For Cost-Effectiveness
1. **Goose + Free MCPs** - Open source, only API costs
2. **Jina AI Reader** - Free tier for URL processing
3. **Brave Search** - 2K free queries/month

### For Enterprise
1. **Claude Web Search** - Integrated, enterprise controls
2. **Bright Data MCP** - Enterprise-grade features
3. **Google CSE MCP** - Scalable with predictable pricing

## Usage Patterns

### Complex Research Workflow
```
User Query � Brave Search � Jina Reader � Claude Analysis � Report Generation
```

### Fact-Checking Pipeline
```
Claim � Perplexity Search � Multiple Sources � Cross-reference � Verification
```

### Content Creation
```
Topic � Tavily Research � Jina Reader � Claude Summarization � Content Draft
```

## Future Considerations

1. **MCP Optimization**: Room for improvement in parameter construction and tool interfaces
2. **Hybrid Approaches**: Combining multiple search sources for better accuracy
3. **Local Models**: Growing interest in self-hosted search solutions
4. **Rate Limiting**: Important for all platforms to avoid API restrictions

## Conclusion

The web search MCP ecosystem offers diverse options for different needs. Goose provides maximum flexibility with its open-source approach, while Claude offers seamless integration for AI workflows. The choice depends on specific requirements for accuracy, privacy, cost, and customization needs.