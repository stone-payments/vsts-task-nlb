[CmdletBinding()]
Param([Switch] $dotSourceOnly)

$script:cluster = $null;

Function Main () {

    # For more information on the VSTS Task SDK:
    # https://github.com/Microsoft/vsts-task-lib
    Trace-VstsEnteringInvocation $MyInvocation;

    Try {
        
        $clusterName = Get-VstsInput -Name "ClusterName" -Require;
        $command = Get-VstsInput -Name "Command" -Require;
        If ($command -Eq "StopClusterNode" -Or $command -Eq "StartClusterNode") {
            $nodeName = Get-VstsInput -Name "NodeName" -Require;
        }
        If ($command -Eq "StopClusterNode") {
            $drainStop = Get-VstsInput -Name "DrainStop" -Require;
            $drainStopTimeout = Get-VstsInput -Name "DrainStopTimeout";
            If ([String]::IsNullOrWhiteSpace($drainStopTimeout)) { $drainStopTimeout = 0; }
            If ($drainStopTimeout -Lt 0) {
                Throw "Drain timeout must be greater than or equal to 0.";
            }
        }

        # Connects to the cluster
        ConnectCluster -ClusterName $clusterName;
        
        # Executes the selected operation.
        If ($command -Eq "ListClusterNodes") {
            ListClusterNodes;
        }
        ElseIf ($command -Eq "StopClusterNode") {
            StopClusterNode -NodeName $nodeName -Drain $drainStop -DrainStopTimeout $drainStopTimeout;
        }
        ElseIf ($command -Eq "StartClusterNode") {
            StartClusterNode -NodeName $nodeName;
        }
        Else {
            Throw "Command not found. ($command)";
        }

        Log "Operation completed.";
    }
    Finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

Function ConnectCluster {
    Param (
        $clusterName
    )

    $script:cluster = Get-NlbCluster $clusterName;
}

Function ListClusterNodes {
    Get-NlbClusterNode -InputObject $script:cluster;
}

Function GetClusterNode {
    Param (
        $nodeName
    )

    Log "Searching for node $($nodeName)";
    $local:node = (Get-NlbClusterNode -InputObject $script:cluster -NodeName $nodeName);
    If (-Not $local:node) { Throw "Node not found."; }
    
    Return $local:node;
}

Function StopClusterNode {
    Param (
        $nodeName,
        $drain,
        $drainStopTimeout
    )

    $local:node = GetClusterNode -NodeName $nodeName;

    Log "Stopping node $($nodeName)...";
    If ($drain) {
        If ($drainStopTimeout -Eq 0) {
            Stop-NlbClusterNode -InputObject $local:node -Drain;
        }
        Else {
            Stop-NlbClusterNode -InputObject $local:node -Drain -Timeout $drainStopTimeout;
        }
    }
    Else {
        Stop-NlbClusterNode -InputObject $local:node;
    }
}

Function StartClusterNode {
    Param (
        $nodeName
    )

    $local:node = GetClusterNode -NodeName $nodeName;

    Log "Starting node $($nodeName)...";
    Start-NlbClusterNode -InputObject $local:node;
}

Function Log
{
    Param (
        $content
    )

    Write-Host $content;
}

If ($dotSourceOnly -Eq $false) {
    Main
}
