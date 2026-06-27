param()
$raw = [Console]::In.ReadToEnd()
$data = $raw | ConvertFrom-Json
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

function Get-ResetHM($ts) {
    $diff = $ts - $now
    if ($diff -le 0) { return "soon" }
    return [DateTimeOffset]::FromUnixTimeSeconds($ts).ToLocalTime().ToString("HH:mm")
}

function Get-ResetDH($ts) {
    $diff = $ts - $now
    if ($diff -le 0) { return "soon" }
    $d = [Math]::Floor($diff / 86400)
    $h = [Math]::Floor(($diff % 86400) / 3600)
    $m = [Math]::Floor(($diff % 3600) / 60)
    if ($d -gt 0) { return "${d}d${h}h" }
    return "${h}h${m}m"
}

$h5_pct   = [int]($data.rate_limits.five_hour.used_percentage)
$h5_reset = $data.rate_limits.five_hour.resets_at
$d7_pct   = [int]($data.rate_limits.seven_day.used_percentage)
$d7_reset = $data.rate_limits.seven_day.resets_at
$ctx_pct  = [int]($data.context_window.used_percentage)

$out = ""
if ($h5_pct) {
    $rst = Get-ResetHM $h5_reset
    $out = "Session:${h5_pct}%(${rst})"
}
if ($d7_pct) {
    $rst = Get-ResetDH $d7_reset
    if ($out) { $out += " " }
    $out += "Week:${d7_pct}%(${rst})"
}
if ($ctx_pct) {
    $filled = [Math]::Floor($ctx_pct / 20)
    $bar = ("▰" * $filled) + ("▱" * (5 - $filled))
    if ($out) { $out += " " }
    $out += "Ctx:${bar}${ctx_pct}%"
}

# JPY rate cache (weekly refresh via ECB/frankfurter.app)
$jpyCachePath = "$HOME\.claude\jpy_rate.cache"
$jpyRate = $null
if (Test-Path $jpyCachePath) {
    $parts = (Get-Content $jpyCachePath -Raw).Trim() -split ":", 2
    if ($parts.Count -eq 2 -and ($now - [long]$parts[0]) -lt 604800) {
        $jpyRate = [double]$parts[1]
    }
}
if ($null -eq $jpyRate) {
    try {
        $resp = Invoke-RestMethod -Uri "https://api.frankfurter.app/latest?from=USD&to=JPY" -TimeoutSec 3
        $jpyRate = $resp.rates.JPY
        "${now}:${jpyRate}" | Set-Content $jpyCachePath
    } catch {}
}

# Budget tracking (monthly, max ¥10,000)
$costUsd = $data.cost.total_cost_usd
if ($null -ne $costUsd -and $null -ne $jpyRate) {
    $budgetCachePath = "$HOME\.claude\cost_budget.cache"
    $curMonth = (Get-Date).ToString("yyyy-MM")
    $cumulativeUsd = 0.0
    $lastSessionUsd = 0.0

    if (Test-Path $budgetCachePath) {
        $parts = (Get-Content $budgetCachePath -Raw).Trim() -split ":", 3
        if ($parts.Count -eq 3 -and $parts[0] -eq $curMonth) {
            $cumulativeUsd  = [double]$parts[1]
            $lastSessionUsd = [double]$parts[2]
        }
    }

    if ($costUsd -lt $lastSessionUsd) {
        $cumulativeUsd += $lastSessionUsd
    }
    "${curMonth}:${cumulativeUsd}:${costUsd}" | Set-Content $budgetCachePath

    $totalUsd = $cumulativeUsd + $costUsd
    $totalJpy = [int]($totalUsd * $jpyRate)

    if ($totalJpy -gt 0) {
        $pct    = [Math]::Min([int]($totalJpy * 100 / 10000), 100)
        $filled = [Math]::Floor($pct / 20)
        $bar    = ("▰" * $filled) + ("▱" * (5 - $filled))
        $warn   = if ($pct -ge 100) { "!!" } else { "" }
        $costFmt  = "{0:F2}" -f $totalUsd
        $jpyWhole = [int]($totalJpy / 1000)
        $jpyDec   = [int](($totalJpy % 1000) / 100)
        if ($out) { $out += " " }
        $out += "Cost:${warn}${bar}`$${costFmt}(¥${jpyWhole}.${jpyDec}k/¥10k)"
    }
}

Write-Host -NoNewline $out
