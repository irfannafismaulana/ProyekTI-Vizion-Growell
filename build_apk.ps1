# Build APK Android GroWell -> dist\GroWell-v<versi>.apk
# Pakai: powershell -ExecutionPolicy Bypass -File build_apk.ps1            (build demo: tombol akun demo tampil)
#        powershell -ExecutionPolicy Bypass -File build_apk.ps1 -Release   (tanpa fitur demo)
# APK memakai Supabase online (supabase_cloud.json); HP tidak bisa menjangkau database lokal laptop.
param([switch]$Release)

Set-Location $PSScriptRoot
if (-not (Test-Path 'supabase_cloud.json')) {
  Write-Host 'supabase_cloud.json belum ada (lihat supabase_cloud.example.json).' -ForegroundColor Yellow
  exit 1
}

$flutterArgs = @('build', 'apk', '--release', '--dart-define-from-file=supabase_cloud.json')
if ($Release) { $flutterArgs += '--dart-define=GROWELL_DEMO=false' }
if (Test-Path 'firebase_config.json') { $flutterArgs += '--dart-define-from-file=firebase_config.json' }

Write-Host "flutter $($flutterArgs -join ' ')" -ForegroundColor Cyan
& flutter @flutterArgs
if ($LASTEXITCODE -ne 0) { Write-Host 'Build gagal.' -ForegroundColor Red; exit 1 }

$version = ((Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value)
$suffix = if ($Release) { '' } else { '-demo' }
New-Item -ItemType Directory -Force 'dist' | Out-Null
$out = "dist\GroWell-v$version$suffix.apk"
Copy-Item 'build\app\outputs\flutter-apk\app-release.apk' $out -Force
Write-Host "Selesai: $out ($([math]::Round((Get-Item $out).Length / 1MB, 1)) MB)" -ForegroundColor Green
