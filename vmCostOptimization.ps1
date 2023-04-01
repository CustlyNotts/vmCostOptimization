Connect-AzAccount

$outputFile = "C:\Temp\vmCostOptimization.csv"

# Get all Azure subscriptions

$subscriptions = Get-AzSubscription

# Create an array to hold the result
$data = @()

# Loop through each subscription
foreach ($subscription in $subscriptions) {

        # Set the subscription context
        Set-AzContext -SubscriptionId $subscription

        # Set the time range to the past 30 days
        $startTime = (Get-Date).AddDays(-30)
        $endTime = Get-Date

        # Get a list of all VMs in the subscription
        $vmList = Get-AzVM

        # Loop through each VM and get its CPU usage over the past 30 days
        foreach ($vm in $vmList) {

        $vmTags = $vm.Tags

        $cpuUsage = Get-AzMetric `

                -ResourceId $vm.Id `

                -TimeGrain 00:05:00 `

                -StartTime $startTime `

                -EndTime $endTime `

                -MetricName "Percentage CPU" `

                -AggregationType Average `

                | Select-Object -ExpandProperty Data

        $CPUCumulative = 0  

        $cpuUsage | ForEach-Object {

                $CPUCumulative += $_.Average

        }

        $TotalCores = 0

        $vmsize = $vm.HardwareProfile.VmSize

        $outer = Get-AzVMSize -VMName $vm.Name -ResourceGroupName $vm.ResourceGroupName | Where-Object {$_.Name -eq $vmsize}

        $Cores = (Get-AzVMSize -VMName $vm.Name -ResourceGroupName $vm.ResourceGroupName | Where-Object { $_.name -eq $VMSize }).NumberOfCores

        $TotalCores += $Cores

        $memUsage = Get-AzMetric `

                -ResourceId $vm.Id `

                -TimeGrain 00:05:00 `

                -StartTime $startTime `

                -EndTime $endTime `

                -MetricName "Available Memory Bytes" `

                -AggregationType Average `

                | Select-Object -ExpandProperty Data

        $MemCumulative = 0  

        $memUsage | ForEach-Object {

                $MemCumulative += $_.Average

        }

        $Memory = $MemCumulative/8640

        $fullMem = $outer.MemoryInMB * 1048576

        $data += [PSCustomObject]@{

                VMName = $vm.Name

                OS = $vm.StorageProfile.OsDisk.OsType

                Location = $vm.Location

                ResourceGroupName = $vm.ResourceGroupName

                SubscriptionId = $subscription.Id

                SubscriptionName = $subscription.Name

                ApplicationName = $vmTags["Application Name"]

                Environment = $vmTags["env"] + $vmTags["ENV"]

                CPU = $CPUCumulative/8640

                MemoryUtilization = (($fullMem - $Memory)/$fullMem) * 100

                VMSize = $vm.HardwareProfile.VmSize

                VMCores = $TotalCores

                VMRAM = $outer.MemoryInMB

                Disks = $vm.StorageProfile.DataDisks.Count

                DiskSize = $vm.StorageProfile.DataDisks | ForEach-Object { $_.DiskSizeGB }

                DiskType = $vm.StorageProfile.DataDisks | ForEach-Object { $_.ManagedDisk.StorageAccountType}

        }

    }

}

# Export the data to a CSV file

$data | Export-Csv -Path $outputFile -NoTypeInformation
