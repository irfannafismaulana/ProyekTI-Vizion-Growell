# Menjalankan GroWell v0.6.
# Pakai: powershell -ExecutionPolicy Bypass -File demo.ps1            (Supabase lokal, data tetap)
#        powershell -ExecutionPolicy Bypass -File demo.ps1 -Reset     (Supabase lokal, kembalikan data contoh)
#        powershell -ExecutionPolicy Bypass -File demo.ps1 -Cloud     (Supabase online, tanpa Docker)
#        tambahkan -Release untuk tampilan rilis (tanpa tombol/akun demo)
param([switch]$Reset, [switch]$Cloud, [switch]$Release)

Set-Location $PSScriptRoot
$cli = 'supabase@2.122.1'

# Argumen tambahan untuk flutter run.
$extra = @()
if ($Release) { $extra += '--dart-define=GROWELL_DEMO=false' }

# PRD F8: konfigurasi Firebase (opsional). firebase_config.json -> dart-define + web/firebase-config.js
if (Test-Path 'firebase_config.json') {
  $fb = Get-Content 'firebase_config.json' -Raw | ConvertFrom-Json
  $js = "self.GROWELL_FIREBASE = { apiKey: '$($fb.FIREBASE_API_KEY)', projectId: '$($fb.FIREBASE_PROJECT_ID)', messagingSenderId: '$($fb.FIREBASE_MESSAGING_SENDER_ID)', appId: '$($fb.FIREBASE_APP_ID_WEB)' };"
  Set-Content -Path 'web/firebase-config.js' -Value $js -Encoding utf8
  $extra += '--dart-define-from-file=firebase_config.json'
  Write-Host 'Push notification: konfigurasi Firebase ditemukan.' -ForegroundColor Green
} else {
  Write-Host 'Push notification nonaktif (firebase_config.json belum ada - lihat PRD.md F8).' -ForegroundColor DarkGray
}

if ($Cloud) {
  if (-not (Test-Path 'supabase_cloud.json')) {
    Write-Host 'supabase_cloud.json belum ada. Salin supabase_cloud.example.json lalu isi URL + publishable key proyek Supabase.' -ForegroundColor Yellow
    exit 1
  }
  Write-Host 'Menjalankan aplikasi dengan Supabase online (http://localhost:8093)...' -ForegroundColor Cyan
  if (-not $Release) { Write-Host '    Akun demo: rani@demo.id / sarah@demo.id / dina@demo.id / admin@demo.id  password: demo123' }
  flutter run -d chrome --web-port 8093 --dart-define-from-file=supabase_cloud.json @extra
  exit $LASTEXITCODE
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Docker Desktop belum berjalan. Buka Docker Desktop, tunggu sampai siap, lalu jalankan lagi.' -ForegroundColor Yellow
  Write-Host '(Atau pakai database online: demo.ps1 -Cloud)' -ForegroundColor Yellow
  exit 1
}

if (-not (Test-Path 'supabase/functions/.env')) {
  Write-Host 'AI (NanoGPT) nonaktif: salin supabase/functions/.env.example menjadi .env lalu isi NANOGPT_API_KEY.' -ForegroundColor DarkGray
}

Write-Host '1/3 Menyalakan Supabase lokal (database + Edge Functions)...' -ForegroundColor Cyan
npx --yes $cli start | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host 'Supabase gagal dinyalakan.' -ForegroundColor Red; exit 1 }

if ($Reset) {
  Write-Host '2/3 Mengembalikan data contoh (db reset)...' -ForegroundColor Cyan
  npx --yes $cli db reset | Out-Null
} else {
  Write-Host '2/3 Menerapkan migrasi baru bila ada (data tetap; tambahkan -Reset untuk data contoh awal)...' -ForegroundColor Cyan
  npx --yes $cli migration up --local | Out-Null
}

Write-Host '3/3 Menjalankan aplikasi di Chrome (http://localhost:8093)...' -ForegroundColor Cyan
Write-Host '    Studio (lihat tabel): http://127.0.0.1:54323   Email OTP (Mailpit): http://127.0.0.1:54324'
if (-not $Release) { Write-Host '    Akun demo: rani@demo.id / sarah@demo.id / dina@demo.id / admin@demo.id  password: demo123' }
flutter run -d chrome --web-port 8093 --dart-define-from-file=supabase_local.json @extra
