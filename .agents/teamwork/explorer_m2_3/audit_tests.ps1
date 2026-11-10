$godot = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$proj = "c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project"
$outDir = "c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\explorer_m2_3"

$tests = Get-ChildItem -Path (Join-Path $proj "tests") -Filter "*.gd"
$summary = @()

foreach ($t in $tests) {
    $errFile = Join-Path $outDir ("check_" + $t.BaseName + ".txt")
    if (Test-Path $errFile) { Remove-Item $errFile }
    $proc = Start-Process -FilePath $godot -ArgumentList @("-d", "--headless", "--path", $proj, "--check-only", "-s", ("res://tests/" + $t.Name)) -Wait -NoNewWindow -PassThru -RedirectStandardError $errFile
    $errContent = ""
    if (Test-Path $errFile) {
        $errContent = (Get-Content $errFile -Raw).Trim()
    }
    Write-Host "=== TEST: $($t.Name) ==="
    if ($errContent.Length -gt 0) {
        Write-Host $errContent
        $summary += [PSCustomObject]@{ File = $t.Name; Warnings = $errContent; Status = "WARNINGS" }
    } else {
        Write-Host "CLEAN (0 warnings)"
        $summary += [PSCustomObject]@{ File = $t.Name; Warnings = "CLEAN"; Status = "CLEAN" }
    }
}

Write-Host "`n=== SUMMARY ==="
$summary | Format-Table -AutoSize
