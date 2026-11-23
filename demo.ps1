# Menjalankan demo GroWell v0.4.
# Pakai: powershell -ExecutionPolicy Bypass -File demo.ps1          (Supabase lokal, data tetap)
#        powershell -ExecutionPolicy Bypass -File demo.ps1 -Reset   (Supabase lokal, kembalikan data contoh)
#        powershell -ExecutionPolicy Bypass -File demo.ps1 -Cloud   (Supabase online, tanpa Docker)
param([switch]$Reset, [switch]$Cloud)

Set-Location $PSScriptRoot

if ($Cloud) {
  if (-not (Test-Path 'supabase_cloud.json')) {
    Write-Host 'supabase_cloud.json belum ada. Salin supabase_cloud.example.json lalu isi URL + publishable key proyek Supabase.' -ForegroundColor Yellow
    exit 1
  }
  Write-Host 'Menjalankan aplikasi dengan Supabase online (http://localhost:8093)...' -ForegroundColor Cyan
  Write-Host '    Akun demo: rani@demo.id / sarah@demo.id / dina@demo.id / admin@demo.id  password: demo123'
  flutter run -d chrome --web-port 8093 --dart-define-from-file=supabase_cloud.json
  exit $LASTEXITCODE
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Docker Desktop belum berjalan. Buka Docker Desktop, tunggu sampai siap, lalu jalankan lagi.' -ForegroundColor Yellow
  Write-Host '(Atau pakai database online: demo.ps1 -Cloud)' -ForegroundColor Yellow
  exit 1
}

Write-Host '1/3 Menyalakan Supabase lokal...' -ForegroundColor Cyan
npx --yes supabase start | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host 'Supabase gagal dinyalakan.' -ForegroundColor Red; exit 1 }

if ($Reset) {
  Write-Host '2/3 Mengembalikan data contoh (db reset)...' -ForegroundColor Cyan
  npx --yes supabase db reset | Out-Null
} else {
  Write-Host '2/3 Menerapkan migrasi baru bila ada (data tetap; tambahkan -Reset untuk data contoh awal)...' -ForegroundColor Cyan
  npx --yes supabase migration up --local | Out-Null
}

Write-Host '3/3 Menjalankan aplikasi di Chrome (http://localhost:8093)...' -ForegroundColor Cyan
Write-Host '    Studio (lihat tabel): http://127.0.0.1:54323   Email OTP (Mailpit): http://127.0.0.1:54324'
Write-Host '    Akun demo: rani@demo.id / sarah@demo.id / dina@demo.id / admin@demo.id  password: demo123'
flutter run -d chrome --web-port 8093 --dart-define-from-file=supabase_local.json
