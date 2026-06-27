#!/bin/bash
# Prepend common Homebrew paths so tools like jq/bc/curl are found
# when launched from GUI apps (Cursor, VS Code) that don't inherit the shell PATH
export PATH="/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin:/snap/bin:$PATH"

input=$(cat)
now=$(date +%s)

h5_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
h5_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
d7_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
d7_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

date_from_epoch() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        LC_ALL=C date -r "$1" "+$2"
    else
        LC_ALL=C date -d "@$1" "+$2"
    fi
}

fmt_reset_hm() {
    local diff=$(( $1 - now ))
    [ $diff -le 0 ] && echo "soon" && return
    echo "$(date_from_epoch "$1" "%H:%M")"
}

fmt_reset_dh() {
    local diff=$(( $1 - now ))
    [ $diff -le 0 ] && echo "soon" && return
    local d=$(( diff / 86400 ))
    local h=$(( (diff % 86400) / 3600 ))
    local m=$(( (diff % 3600) / 60 ))
    if [ $d -gt 0 ]; then
        echo "${d}d${h}h"
    else
        echo "${h}h${m}m"
    fi
}

ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)

# JPY rate cache (weekly refresh via ECB/frankfurter.app)
JPY_CACHE="$HOME/.claude/jpy_rate.cache"
jpy_rate=""
if [ -f "$JPY_CACHE" ]; then
    cached_ts=$(cut -d: -f1 "$JPY_CACHE")
    cached_rate=$(cut -d: -f2 "$JPY_CACHE")
    if [ $(( now - cached_ts )) -lt 604800 ] && [ -n "$cached_rate" ]; then
        jpy_rate="$cached_rate"
    fi
fi
if [ -z "$jpy_rate" ]; then
    fetched=$(curl -sf --max-time 3 "https://api.frankfurter.app/latest?from=USD&to=JPY" | jq -r '.rates.JPY // empty')
    if [ -n "$fetched" ]; then
        jpy_rate="$fetched"
        echo "${now}:${fetched}" > "$JPY_CACHE"
    fi
fi

out=""
if [ -n "$h5_pct" ]; then
    rst=$(fmt_reset_hm "$h5_reset")
    out="Session:${h5_pct}%(${rst})"
fi
if [ -n "$d7_pct" ]; then
    rst=$(fmt_reset_dh "$d7_reset")
    [ -n "$out" ] && out="$out "
    out="${out}Week:${d7_pct}%(${rst})"
fi
if [ -n "$ctx_pct" ]; then
    filled=$(( ctx_pct / 20 ))
    empty=$(( 5 - filled ))
    bar=""; for i in $(seq 1 $filled 2>/dev/null); do bar="${bar}▰"; done; for i in $(seq 1 $empty 2>/dev/null); do bar="${bar}▱"; done
    [ -n "$out" ] && out="$out "
    out="${out}Ctx:${bar}${ctx_pct}%"
fi
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$cost_usd" ] && [ -n "$jpy_rate" ]; then
    BUDGET_CACHE="$HOME/.claude/cost_budget.cache"
    cur_month=$(date +%Y-%m)
    cumulative_usd="0"
    last_session_usd="0"

    if [ -f "$BUDGET_CACHE" ]; then
        cached_month=$(cut -d: -f1 "$BUDGET_CACHE")
        if [ "$cached_month" = "$cur_month" ]; then
            cumulative_usd=$(cut -d: -f2 "$BUDGET_CACHE")
            last_session_usd=$(cut -d: -f3 "$BUDGET_CACHE")
        fi
    fi

    # Detect new session (cost reset below last known value)
    if [ "$(echo "$cost_usd < $last_session_usd" | bc)" = "1" ]; then
        cumulative_usd=$(echo "$cumulative_usd + $last_session_usd" | bc)
    fi
    echo "${cur_month}:${cumulative_usd}:${cost_usd}" > "$BUDGET_CACHE"

    total_usd=$(echo "$cumulative_usd + $cost_usd" | bc)
    total_jpy=$(echo "scale=2; $total_usd * $jpy_rate" | bc | cut -d. -f1)

    if [ "${total_jpy:-0}" -gt 0 ] 2>/dev/null; then
        budget_jpy=10000
        pct=$(( total_jpy * 100 / budget_jpy ))
        [ $pct -gt 100 ] && pct=100
        filled=$(( pct / 20 ))
        empty=$(( 5 - filled ))
        bar=""; for i in $(seq 1 $filled 2>/dev/null); do bar="${bar}▰"; done; for i in $(seq 1 $empty 2>/dev/null); do bar="${bar}▱"; done
        cost_fmt=$(printf "%.2f" "$total_usd")
        jpy_whole=$(( total_jpy / 1000 ))
        jpy_dec=$(( (total_jpy % 1000) / 100 ))
        [ -n "$out" ] && out="$out "
        warn=""
        [ $pct -ge 100 ] && warn="!!"
        out="${out}Cost:${warn}${bar}\$${cost_fmt}(¥${jpy_whole}.${jpy_dec}k/¥10k)"
    fi
fi

printf "%s" "$out"
