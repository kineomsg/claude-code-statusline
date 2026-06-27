# claude-code-statusline

A statusline for [Claude Code](https://claude.ai/code) that shows rate limits, context usage, and monthly cost in Japanese Yen.

## Preview

```
Session:45%(14:30) Week:2d30m(3d12h) Ctx:▰▰▱▱▱40% Cost:▰▰▰▱▱$0.15(¥5.0k/¥10k)
```

Over budget:

```
Session:45%(14:30) Week:2d30m(3d12h) Ctx:▰▰▱▱▱40% Cost:!!▰▰▰▰▰$70.00(¥10.8k/¥10k)
```

## Features

| Field | Description |
|---|---|
| `Session:XX%(HH:MM)` | 5-hour rate limit usage and reset time |
| `Week:XX%(Xd Xh)` | 7-day rate limit usage and time until reset |
| `Ctx:▰▰▱▱▱XX%` | Context window usage (5-segment bar) |
| `Cost:▰▱▱▱▱$X.XX(¥X.Xk/¥10k)` | Monthly cost in USD + JPY with budget bar |

**Cost display behavior:**
- Accumulates cost across sessions within the same month
- Resets automatically on the 1st of each month
- Exchange rate fetched weekly from ECB (European Central Bank) via [frankfurter.app](https://www.frankfurter.app/)
- **Not shown on subscription plans (Pro/Max)** — cost data is only available on API key or Azure AI Foundry usage
- Shows `!!` prefix when the ¥10,000 monthly budget is exceeded

## Platform Support

| Platform | Script | Requirements |
|---|---|---|
| Linux | `statusline.sh` | `jq`, `bc`, `curl` |
| macOS | `statusline.sh` | `jq`, `bc`, `curl` (via Homebrew) |
| WSL | `statusline.sh` | `jq`, `bc`, `curl` |
| Git Bash (Windows) | `statusline.sh` | `jq`, `curl`, `bc` |
| Native Windows | `statusline.ps1` | PowerShell 5.1+ (no extra installs needed) |

## Setup

### Linux / macOS / WSL

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

Make the script executable:

```bash
chmod +x ~/.claude/statusline.sh
```

### Native Windows (PowerShell)

Add to `%USERPROFILE%\.claude\settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -File ~/.claude/statusline.ps1"
  }
}
```

## Files

```
~/.claude/
├── statusline.sh          # Linux / macOS / WSL
├── statusline.ps1         # Native Windows
├── jpy_rate.cache         # Exchange rate cache (auto-generated)
└── cost_budget.cache      # Monthly cost cache (auto-generated)
```

### Cache file formats

**`jpy_rate.cache`**
```
<UnixTimestamp>:<JPY rate>
e.g. 1751234567:157.23
```

**`cost_budget.cache`**
```
<YYYY-MM>:<cumulative USD>:<last session USD>
e.g. 2026-06:0.32:0.15
```

## Customization

To change the monthly budget (default: ¥10,000):

`statusline.sh`:
```bash
budget_jpy=10000  # change this value
```

`statusline.ps1`:
```powershell
$pct = [Math]::Min([int]($totalJpy * 100 / 10000), 100)  # change 10000
```

## Notes

- **Subscription plans (Pro/Max) do not expose cost data** — the Cost field will not appear. Only API key usage and Azure AI Foundry are supported.
- When using Azure AI Foundry, costs are estimated based on Anthropic's public pricing and may differ from your actual Azure bill

## License

MIT
