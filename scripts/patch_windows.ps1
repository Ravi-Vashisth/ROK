param(
  [switch]$FinalizeBundle
)

$ErrorActionPreference = 'Stop'

if (-not $FinalizeBundle) {
  $win32WindowPath = "windows\runner\win32_window.cpp"
  if (Test-Path $win32WindowPath) {
    $content = Get-Content -Raw -Path $win32WindowPath -Encoding UTF8
    if ($content -notmatch 'WM_GETMINMAXINFO') {
      Write-Host "Patching $win32WindowPath with DPI-aware minimum window size (420x560)..."
      $minMaxCase = @"
    case WM_GETMINMAXINFO: {
      MINMAXINFO* minMaxInfo = reinterpret_cast<MINMAXINFO*>(lparam);
      UINT dpi = GetDpiForWindow(hwnd);
      if (dpi == 0) dpi = 96;
      minMaxInfo->ptMinTrackSize.x = MulDiv(420, dpi, 96);
      minMaxInfo->ptMinTrackSize.y = MulDiv(560, dpi, 96);
      return 0;
    }

    case WM_DESTROY:
"@
      if ($content -match 'case WM_DESTROY:') {
        $patched = $content -replace 'case WM_DESTROY:', $minMaxCase
        Set-Content -Path $win32WindowPath -Value $patched -Encoding UTF8
        Write-Host "Successfully added WM_GETMINMAXINFO guard to $win32WindowPath."
      } else {
        Write-Warning "Could not locate case WM_DESTROY in $win32WindowPath; skipping min-size patch."
      }
    }
  }
} else {
  $releaseDir = "build\windows\x64\runner\Release"
  if (Test-Path $releaseDir) {
    $exeFiles = Get-ChildItem -Path $releaseDir -Filter "*.exe"
    if ($exeFiles.Count -eq 0) {
      throw "No .exe executable found in $releaseDir!"
    }
    $readmePath = Join-Path $releaseDir "README_RUNTIME.txt"
    $readmeContent = @"
Offline Billing & Invoicing Desktop Suite (Windows x64)
========================================================

1. Distribution: Keep all files in this folder together (including *.dll and the data\ directory) when moving or running the application.
2. Runtime Prerequisite: Requires Windows 10/11 (64-bit) and the Microsoft Visual C++ 2015-2022 Redistributable (x64):
   https://aka.ms/vs/17/release/vc_redist.x64.exe
3. Local Data Storage: All invoices, clients, expenses, and settings are stored offline in your local Windows AppData SQLite ledger. Use Settings -> Database Backup to export JSON snapshots.
"@
    Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
    Write-Host "Bundled Windows runtime guide at $readmePath."
  }
}
