Function Get-NlbCluster {
    Param (
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )

    Throw "Get-NlbCluster not implemented."
}

Function Get-NlbClusterNode {
    Param (
        [Parameter(ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName=$true)]
        $InputObject,
        $NodeName
    )

    Throw "Get-NlbClusterNode not implemented."
}

Function Stop-NlbClusterNode {
    Param (
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,
        $HostName,
        [Switch] $Drain,
        $Timeout
    )

    Throw "Get-NlbClusterNode not implemented."
}

Function Start-NlbClusterNode {
    Param (
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,
        $HostName
    )

    Throw "Get-NlbClusterNode not implemented."
}

