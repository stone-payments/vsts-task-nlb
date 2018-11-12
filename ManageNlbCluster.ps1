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
    $script:cluster | Get-NlbClusterNode;
}

Function GetClusterNode {
    Param (
        $nodeName
    )

    Log "Searching for node $($nodeName)";
    # # # $local:node = ($script:cluster | Get-NlbClusterNode $nodeName);
    # $local:node = ($script:cluster | Get-NlbClusterNode -NodeName $nodeName);
    $local:node = ($script:cluster | Get-NlbClusterNode);
    # $local:node = (Get-NlbClusterNode -NodeName $nodeName);
    # # # If (-Not $local:node) { Throw "Node not found."; }
    
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
            $local:node | Stop-NlbClusterNode -Drain;
        }
        Else {
            $local:node | Stop-NlbClusterNode -Drain -Timeout $drainStopTimeout;
        }
    }
    Else {
        $local:node | Stop-NlbClusterNode;
    }
}

Function StartClusterNode {
    Param (
        $nodeName
    )

    $local:node = GetClusterNode -NodeName $nodeName;

    Log "Starting node $($nodeName)...";
    $local:node | Start-NlbClusterNode;
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
