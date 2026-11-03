# Menjalankan demo GroWell v0.3 dengan database Supabase lokal.
# Pakai: powershell -ExecutionPolicy Bypass -File demo.ps1          (data tetap)
#        powershell -ExecutionPolicy Bypass -File demo.ps1 -Reset   (kembalikan data contoh)
param([switch]$Reset)

Set-Location $PSScriptRoot

docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Docker Desktop belum berjalan. Buka Docker Desktop, tunggu sampai siap, lalu jalankan lagi.' -ForegroundColor Yellow
  exit 1
}

Write-Host '1/3 Menyalakan Supabase lokal...' -ForegroundColor Cyan
npx --yes supabase start | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host 'Supabase gagal dinyalakan.' -ForegroundColor Red; exit 1 }

if ($Reset) {
  Write-Host '2/3 Mengembalikan data contoh (db reset)...' -ForegroundColor Cyan
  npx --yes supabase db reset | Out-Null
} else {
  Write-Host '2/3 Data database dipakai apa adanya (tambahkan -Reset untuk data contoh awal).' -ForegroundColor Cyan
}

Write-Host '3/3 Menjalankan aplikasi di Chrome (http://localhost:8093)...' -ForegroundColor Cyan
Write-Host '    Studio (lihat tabel): http://127.0.0.1:54323   Email OTP (Mailpit): http://127.0.0.1:54324'
Write-Host '    Akun demo: rani@demo.id / sarah@demo.id / dina@demo.id / admin@demo.id  password: demo123'
flutter run -d chrome --web-port 8093 --dart-define-from-file=supabase_local.json
