param(
    $outputpath = ".\"
)

# Connect and set the subscription context
Connect-AzAccount 

$subscriptionIds = Get-AzSubscription | Select-Object -ExpandProperty Id


# Initialize an empty array to store results
$resultsArray = @()

#

foreach ($subscriptionId in $subscriptionIds) {

    # Set the subscription context
    Set-AzContext -SubscriptionId $subscriptionId

    # Define time range
    $timeFrame = (Get-Date).AddDays(-30)
    $startDate = $timeFrame.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

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
            $metricNames = @("allocated_data_storage", "storage", "cpu_percent", "sql_instance_memory_percent", "dtu_consumption_percent", "dtu_limit", "dtu_used")
            $metricNamespace = "Microsoft.Sql/servers/databases"

            # Initialize an object to store metrics data
            $metricsData = [PSCustomObject]@{
                'SubscriptionName'              = $subscriptionName
                'SqlServerName'                 = $sqlServerName
                'DatabaseName'                  = $databaseName
                'ResourceGroupName'             = $resourceGroupName
                'databaseSkuName'               = $databaseSkuName
                'CurrentServiceObjectiveName'   = $CurrentServiceObjectiveName
                'zoneRedundant'                 = $database.ZoneRedundant
                'autoPause'                     = $database.AutoPauseDelayInMinutes
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

                # Filter
                if ($database.databaseSkuName -like 'System*') {
                    # Skip system databases
                    continue
                }

                # Calculate the average if there are non-null, non-zero data points
                if ($dataPointCount -gt 0) {
                    Write-Host "$metricName"
                    $averageValue = $totalMetricCount / $dataPointCount
                        
                    # Additional formatting for specific metrics
                    if ($metricName -eq "cpu_percent") {
                        $averageValue = [math]::Round($averageValue, 5)
                    }
                    if ($metricName -eq "sql_instance_memory_percent") {
                        $averageValue = [math]::Round($averageValue, 2)
                    }
                    if ($metricName -eq "storage" -or $metricName -eq "allocated_data_storage") {
                        $averageValue = [math]::Round($averageValue / (1024 * 1024), 3)
                    }
                    if ($metricName -eq "dtu_used") {
                        $averageValue = [math]::Round($averageValue, 3)
                    }
                    $metricsData | Add-Member -MemberType NoteProperty -Name $metricName -Value $averageValue -Force
                }
            }
            # Add metrics data to results array
            $resultsArray += $metricsData
            $resultsArray
        }
    }
}
# Save results to CSV file (overwrite if the file exists)
$csvFilePath = "$outputpath\data.csv"
$resultsArray | Select-Object -Property SubscriptionName, SqlServerName, DatabaseName, ResourceGroupName, databaseSkuName, CurrentServiceObjectiveName, zoneRedundant, autoPause,
@{Name = "Data space allocated"; Expression = { $_.allocated_data_storage } }, 
@{Name = "Data space used"; Expression = { $_.storage } }, 
@{Name = "Percentage CPU"; Expression = { $_.cpu_percent } },
@{Name = "DTU Limit"; Expression = { $_.dtu_limit } },
@{Name = "DTU Used Average"; Expression = { $_.dtu_used } },
@{Name = "DTU Consumption Percentage"; Expression = { [math]::(($_.dtu_used / $_.dtu_limit)*100),3 } },
sql_instance_memory_percent | Export-Csv -Path $csvFilePath -NoTypeInformation -Force

Write-Host "Results saved to $csvFilePath"