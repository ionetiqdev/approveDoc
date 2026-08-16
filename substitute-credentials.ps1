param(
    [string]$Url,
    [string]$AnonKey
)
$file = 'assets\js\supabase-client.js'
$content = Get-Content $file -Raw
$content = $content -replace '\{\{SUPABASE_URL\}\}', $Url
$content = $content -replace '\{\{SUPABASE_ANON_KEY\}\}', $AnonKey
Set-Content $file $content
