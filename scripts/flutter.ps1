param()
# Preserve Flutter flags such as -d and -v; advanced PowerShell parameters
# would otherwise consume them as Debug and Verbose switches.
$taskFlutterArguments = @($args)
$ErrorActionPreference = 'Stop'
$taskProjectRoot = Split-Path -Parent $PSScriptRoot
$taskLocalSdk = Join-Path $taskProjectRoot '.tooling\flutter'
$taskAndroidSdkFile = Join-Path $taskProjectRoot '.tooling\android-sdk-path.txt'
if (Test-Path -LiteralPath $taskAndroidSdkFile) {
    $taskAndroidSdk = (Get-Content -LiteralPath $taskAndroidSdkFile -Raw).Trim()
    if (Test-Path -LiteralPath (Join-Path $taskAndroidSdk 'platform-tools')) {
        $env:ANDROID_HOME = $taskAndroidSdk
        $env:ANDROID_SDK_ROOT = $taskAndroidSdk
    }
}
if (Test-Path -LiteralPath (Join-Path $taskProjectRoot '.tooling\bin')) {
    $env:PATH = (Join-Path $taskProjectRoot '.tooling\bin') + ';' + $env:PATH
}
if (Test-Path -LiteralPath (Join-Path $taskLocalSdk 'bin\cache\flutter_tools.snapshot')) {
    $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
    & (Join-Path $taskLocalSdk 'bin\cache\dart-sdk\bin\dart.exe') (Join-Path $taskLocalSdk 'bin\cache\flutter_tools.snapshot') --no-version-check @taskFlutterArguments
} else {
    & flutter @taskFlutterArguments
}
exit $LASTEXITCODE
