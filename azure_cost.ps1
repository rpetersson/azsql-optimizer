param(
    [string]$skuName = "GP_Gen5_2"
)

# Function for calling a REST endpoint to get Azure cost data
$uri = "https://prices.azure.com/api/retail/prices?currencyCode='EUR'&`$filter=serviceFamily eq 'Databases'"

$response = Invoke-Webrequest -Method Get -Uri $uri

$response.Content | ConvertFrom-Json | Where-Object { $_.skuName -eq "vCore" }