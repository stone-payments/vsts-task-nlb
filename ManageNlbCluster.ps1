[CmdletBinding()]
Param([Switch] $dotSourceOnly)

Function Main () {

    # For more information on the VSTS Task SDK:
    # https://github.com/Microsoft/vsts-task-lib
    Trace-VstsEnteringInvocation $MyInvocation;

    Try {
        
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

        # Executes the selected operation.
        If ($command -Eq "StopClusterNode") {
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

Function StopClusterNode {
    Param (
        $nodeName,
        $drain,
        $drainStopTimeout
    )

    Log "Stopping node $($nodeName)...";
    If ($drain) {
        If ($drainStopTimeout -Eq 0) {
            Stop-NlbClusterNode -HostName $nodeName -Drain;
        }
        Else {
            Stop-NlbClusterNode -HostName $nodeName -Drain -Timeout $drainStopTimeout;
        }
    }
    Else {
        Stop-NlbClusterNode -HostName $nodeName;
    }
}

Function StartClusterNode {
    Param (
        $nodeName
    )

    Log "Starting node $($nodeName)...";
    Start-NlbClusterNode -HostName $nodeName;
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
