param(
    $subscriptionId = "e1aa94ea-64ec-41ad-863a-e68b5cee827e",
    $outputpath = ".\"
)

# Connect and set the subscription context
Connect-AzAccount -SubscriptionId $subscriptionId
Set-AzContext -SubscriptionId $subscriptionId

# Define time range
$timeFrame = (Get-Date).AddDays(-30)
$startDate = $timeFrame.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$endDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Initialize an empty array to store results
$resultsArray = @()

# Get current subscription name
$subscriptionName = (Get-AzContext).Subscription.Name

# Get SQL server details
$sqlServers = Get-AzSqlServer

# Get metrics data for each SQL server
foreach ($sqlServer in $sqlServers) {

    $sqlServerName = $sqlServer.ServerName
    $resourceGroupName = $sqlServer.ResourceGroupName

    # Get databases for the current SQL server
    $databases = Get-AzSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $sqlServerName

    foreach ($database in $databases) {

        $databaseName = $database.DatabaseName
        $databaseResourceId = $database.ResourceId
        $databaseSkuName = $database.SkuName
        $CurrentServiceObjectiveName = $database.CurrentServiceObjectiveName

        # Define metrics parameters
        $metricNames = @("allocated_data_storage", "storage", "cpu_percent", "sql_instance_memory_percent", "dtu_consumption_percent","dtu_limit","dtu_used")
        $metricNamespace = "Microsoft.Sql/servers/databases"

        # Initialize an object to store metrics data
        $metricsData = [PSCustomObject]@{
            'SubscriptionName'  = $subscriptionName
            'SqlServerName'     = $sqlServerName
            'DatabaseName'      = $databaseName
            'ResourceGroupName' = $resourceGroupName
            'databaseSkuName'   = $databaseSkuName
            'CurrentServiceObjectiveName' = $CurrentServiceObjectiveName
        }

        # Get metrics data for each metric
        foreach ($metricName in $metricNames) {

            $sqlMetric = Get-AzMetric -ResourceId $databaseResourceId -StartTime $startDate -EndTime $endDate -MetricNamespace $metricNamespace -MetricName $metricName -AggregationType Average -DetailedOutput -WarningAction SilentlyContinue
            $sqlMetrics = $sqlMetric.Data

            # Calculate the total count for the current metric
            $totalMetricCount = 0
            $dataPointCount = 0
            $nonZeroDataPointCount = 0

            foreach ($dataPoint in $sqlMetrics) {
                $value = $dataPoint.Average

                # Exclude null or zero values
                if ($null -ne $value) {
                    $totalMetricCount += $value
                    $dataPointCount++

                    if ($value -ne 0) {
                        $nonZeroDataPointCount++
                    }
                }
            }

            # Calculate the average if there are non-null, non-zero data points
            if ($dataPointCount -gt 0) {
                Write-Host "$metricName"
                $averageValue = $totalMetricCount / $dataPointCount
                
                # Additional formatting for specific metrics
                if ($metricName -eq "cpu_percent") {
                    $averageValue = [math]::Round($metricsData.cpu_percent, 3)
                }
                if ($metricName -eq "sql_instance_memory_percent") {
                    $averageValue = [math]::Round($metricsData.sql_instance_memory_percent, 2)
                }
                if ($metricName -eq "storage" -or $metricName -eq "allocated_data_storage") {
                    $averageValue = [math]::Round($averageValue / (1024 * 1024), 3)
                }
                if ($metricName -eq "dtu_used") { #Some bug here...
                    $averageValue #= [math]::Round($metricName.dtu_used, 3)
                }
                $metricsData | Add-Member -MemberType NoteProperty -Name $metricName -Value $averageValue -Force
            }
            else {
                $metricsData | Add-Member -MemberType NoteProperty -Name $metricName -Value 0 -Force
            }
        }

        # Add metrics data to results array
        $resultsArray += $metricsData
    }
}

# Save results to CSV file (overwrite if the file exists)
$csvFilePath = "$outputpath\data.csv"
$resultsArray | Select-Object -Property SubscriptionName, SqlServerName, DatabaseName, ResourceGroupName, databaseSkuName, CurrentServiceObjectiveName, 
@{Name = "Data space allocated"; Expression = { $_.allocated_data_storage }}, 
@{Name = "Data space used"; Expression = { $_.storage }}, 
@{Name = "Percentage CPU"; Expression = { $_.cpu_percent }},
@{Name = "DTU Limit"; Expression = { $_.dtu_limit }},
@{Name = "DTU Used Average"; Expression = { $_.dtu_used }},
sql_instance_memory_percent | Export-Csv -Path $csvFilePath -NoTypeInformation -Force



Write-Host "Results saved to $csvFilePath"