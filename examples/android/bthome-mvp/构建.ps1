$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot
try {
    & .\gradlew.bat :app:assembleDebug --console=plain | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "构建失败，Gradle 退出码 $LASTEXITCODE"
    }
    (Resolve-Path -LiteralPath 'app/build/outputs/apk/debug/app-debug.apk').Path
} finally {
    Pop-Location
}
