# Claude Code Integration

The app exports quota data to `~/Library/Application Support/ZaiUsageMenuBar/quota.txt` so it can be displayed in Claude Code's status line.

## Setup

### 1. Create status line script

Save the following to `~/.claude/statusline.sh`:

```bash
#!/bin/bash
QUOTA_FILE="$HOME/Library/Application Support/ZaiUsageMenuBar/quota.txt"
if [ -f "$QUOTA_FILE" ]; then
    LINE=$(cat "$QUOTA_FILE")
    PCT=$(echo "$LINE" | cut -d',' -f1 | tr -d '% ' )
    TOKENS=$(echo "$LINE" | cut -d',' -f2 | xargs)
    RESET_AT=$(echo "$LINE" | cut -d',' -f3 | xargs)
    if [ "$PCT" -le 10 ]; then
        COLOR='\033[31m'
    elif [ "$PCT" -le 30 ]; then
        COLOR='\033[33m'
    else
        COLOR='\033[32m'
    fi
    NC='\033[0m'
    echo -e "${COLOR}GLM: ${PCT}% rest, ${TOKENS}, 5h@${RESET_AT}${NC}"
else
    echo "GLM: --"
fi
```

Make it executable:

```bash
chmod +x ~/.claude/statusline.sh
```

### 2. Configure Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

## Display

| State | Example |
|-------|---------|
| App running | `GLM: 55% rest, 1.2M, 5h@13:33` (color-coded) |
| App not running | `GLM: --` |

- **Percentage** — Remaining quota (red ≤10%, orange ≤30%, green otherwise)
- **Tokens** — Today's total token usage (e.g. `1.2M`, `456.7K`)
- **5h@** — Time when the 5-hour quota window resets

The quota file is automatically cleaned up when the app exits, preventing stale data.

## Data Format

`quota.txt` contains a single line:

```
55%, 1.2M, 13:33
```

Fields: `remaining%, todayTokens, 5hResetTime`

Updated automatically by the app (every 30s when active, up to 5min when idle).
