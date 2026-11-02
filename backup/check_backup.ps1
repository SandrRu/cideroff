$path = Join-Path $PSScriptRoot 'CiderOff_Backup_1793046267315.ciderbak'
$json = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
Write-Output 'Top-level keys:'
$json.PSObject.Properties.Name | ForEach-Object { Write-Output (' - ' + $_) }
Write-Output ''
Write-Output ('version = ' + $json.version)
Write-Output ('batches = ' + ($json.batches | Measure-Object).Count)
Write-Output ('batchRecipeLinks = ' + ($json.batchRecipeLinks | Measure-Object).Count)
Write-Output ('history = ' + ($json.history | Measure-Object).Count)
Write-Output ('recipes = ' + ($json.recipes | Measure-Object).Count)
Write-Output ('templates = ' + ($json.templates | Measure-Object).Count)
Write-Output ('yeasts = ' + ($json.yeasts | Measure-Object).Count)
Write-Output ('drinkTypes = ' + ($json.drinkTypes | Measure-Object).Count)
Write-Output ('sweetenerTypes = ' + ($json.sweetenerTypes | Measure-Object).Count)