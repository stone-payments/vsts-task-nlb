# Find and import source script.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$systemUnderTest = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$srcDir = "$here\.."
. "$srcDir\$systemUnderTest" -dotSourceOnly

# Import vsts sdk.
$vstsSdkPath = Join-Path $PSScriptRoot ..\ps_modules\VstsTaskSdk\VstsTaskSdk.psm1 -Resolve
Import-Module -Name $vstsSdkPath -Prefix Vsts -ArgumentList @{ NonInteractive = $true } -Force

If (-Not (Get-Module -Name NetworkLoadBalancingClusters -ListAvailable)) {
    $nlbMockPath = Join-Path $PSScriptRoot ..\ps_modules\NlbMock\Nlb.ps1 -Resolve
    . $nlbMockPath
}

Describe "Main" {

    # General mocks needed to control flow and avoid throwing errors.
    Mock Trace-VstsEnteringInvocation -MockWith {}
    Mock Trace-VstsLeavingInvocation -MockWith {}
    Mock Log -MockWith {}

    $clusterIP = "10.0.0.1"
    Context "When listing the nodes" {

        Mock Get-VstsInput -ParameterFilter { $Name -Eq "ClusterName" } -MockWith { return $clusterIP } 
        Mock Get-VstsInput -ParameterFilter { $Name -Eq "Command" } -MockWith { return "ListClusterNodes" }
        Mock ConnectCluster -MockWith {}

        It "It should call ListClusterNodes" {

            Mock ListClusterNodes {}

            Main

            Assert-MockCalled Get-VstsInput -Times 1 -Exactly -ParameterFilter { $Name -Eq "ClusterName" }
            Assert-MockCalled Get-VstsInput -Times 1 -Exactly -ParameterFilter { $Name -Eq "Command" }
            Assert-MockCalled ConnectCluster -Times 1 -Exactly -Scope It
            Assert-MockCalled ListClusterNodes -Times 1 -Exactly
        }
    }

    Context "When stopping the node" {
        
        Mock Get-VstsInput -ParameterFilter { $Name -Eq "ClusterName" } -MockWith { return $clusterIP }
        Mock Get-VstsInput -ParameterFilter { $Name -Eq "Command" } -MockWith { return "StopClusterNode" }
        Mock ConnectCluster -MockWith {}

        It "Given NodeIP = '<nodeIP>', Drain = <drain>, Timeout = <timeout> - It should call StopClusterNode" -TestCases $(
            @{ nodeIP = '10.0.0.2'; drain = $false; timeout = 0 }
            @{ nodeIP = "10.0.0.2"; drain = $true; timeout = $null }
            @{ nodeIP = "10.0.0.2"; drain = $true; timeout = "" }
            @{ nodeIP = "10.0.0.2"; drain = $true; timeout = 0 }
            @{ nodeIP = "10.0.0.2"; drain = $true; timeout = 1 }
        ) {
            Param (
                $nodeIP,
                $drain,
                $timeout
            )
            
            If ([String]::IsNullOrWhiteSpace($timeout)) { $timeout = 0; }
            
            Mock Get-VstsInput -ParameterFilter { $Name -Eq "NodeName" } -MockWith { return $nodeIP }
            Mock Get-VstsInput -ParameterFilter { $Name -Eq "DrainStop" } -MockWith { return $drain }
            Mock Get-VstsInput -ParameterFilter { $Name -Eq "DrainStopTimeout" } -MockWith { return $timeout }
            Mock GetClusterNode -ParameterFilter { $nodeName -Eq $nodeIP } -MockWith {}
            Mock StopClusterNode -ParameterFilter { $nodeName -Eq $nodeIP -And $drainStop -Eq $drain -And $drainStopTimeout -Eq $timeout } -MockWith {}

            Main

            Assert-MockCalled Get-VstsInput -Times 1 -Exactly -Scope It -ParameterFilter { $Name -Eq "ClusterName" }
            Assert-MockCalled Get-VstsInput -Times 1 -Exactly -Scope It -ParameterFilter { $Name -Eq "Command" }
            Assert-MockCalled Get-VstsInput -Times 1 -Exactly -Scope It -ParameterFilter { $Name -Eq "DrainStopTimeout" }
            Assert-MockCalled ConnectCluster -Times 1 -Exactly -Scope It
            Assert-MockCalled StopClusterNode -Times 1 -Exactly -Scope It -ParameterFilter { $nodeName -Eq $nodeIP -And [System.Object]::Equals($drainStopTimeout, $timeout) }
        }
    }

    Context "When starting the node" {

        Mock Get-VstsInput -ParameterFilter { $Name -Eq "ClusterName" } -MockWith { return $clusterIP }
        Mock Get-VstsInput -ParameterFilter { $Name -Eq "Command" } -MockWith { return "StartClusterNode" }
        Mock ConnectCluster -MockWith {}

        It "It should call StartClusterNode" {

            $nodeIP = "10.0.0.2";

            Mock Get-VstsInput -ParameterFilter { $Name -Eq "NodeName" } -MockWith { return $nodeIP }
            Mock GetClusterNode -ParameterFilter { $nodeName -Eq $nodeIP } -MockWith {}
            Mock StartClusterNode -ParameterFilter { $nodeName -Eq $nodeIP } -MockWith {}

            Main

            Assert-MockCalled Get-VstsInput -Times 1 -Exactly -Scope It -ParameterFilter { $Name -Eq "ClusterName" }
            Assert-MockCalled Get-VstsInput -Times 1 -Exactly -Scope It -ParameterFilter { $Name -Eq "Command" }
            Assert-MockCalled ConnectCluster -Times 1 -Exactly -Scope It
            Assert-MockCalled StartClusterNode -Times 1 -Exactly -Scope It -ParameterFilter { $nodeName -Eq $nodeIP }
        }
    }

    Context "When supplying invalid arguments" {

        Mock ConnectCluster -MockWith {}

        It "Given invalid Command - It should throw an exception" {
        
            $command = "InvalidCommand";

            Mock Get-VstsInput -ParameterFilter { $Name -Eq "ClusterName" } -MockWith { return $clusterIP }
            Mock Get-VstsInput -ParameterFilter { $Name -Eq "Command" } -MockWith { return $command }
                
            {Main} | Should -Throw "Command not found. ($command)"
        }

        It "Given DrainStopTimeout -Lt 0 - It should throw an exception" {
        
            $nodeIP = "10.0.0.2";
            $drain = $true;
            $timeout = -1;

            Mock Get-VstsInput -ParameterFilter { $Name -Eq "ClusterName" } -MockWith { return $clusterIP }
            Mock Get-VstsInput -ParameterFilter { $Name -Eq "Command" } -MockWith { return "StopClusterNode" }
            Mock Get-VstsInput -ParameterFilter { $Name -Eq "NodeName" } -MockWith { return $nodeIP }
            Mock Get-VstsInput -ParameterFilter { $Name -Eq "DrainStop" } -MockWith { return $drain }
            Mock Get-VstsInput -ParameterFilter { $Name -Eq "DrainStopTimeout" } -MockWith { return $timeout }
                
            {Main} | Should -Throw "Drain timeout must be greater than or equal to 0."
        }
    }
}

Describe "ConnectCluster" {

    Mock Log -MockWith {}

    $clusterIP = "10.0.0.1"
    Context "When connecting to a cluster" {

        It "It should connect" {

            Mock Get-NlbCluster -ParameterFilter { $InputObject -Eq $clusterIP } -MockWith {}

            ConnectCluster -ClusterName $clusterIP

            Assert-MockCalled Get-NlbCluster -Times 1 -Exactly -Scope It
        }
    }
}

Describe "ListClusterNodes" {

    Mock Log -MockWith {}

    Context "When connected to a cluster" {

        It "It should list the nodes" {

            Mock Get-NlbClusterNode -ParameterFilter { $InputObject -Eq $null } -MockWith {}

            ListClusterNodes

            Assert-MockCalled Get-NlbClusterNode -Times 1 -Exactly -Scope It
        }
    }
}

Describe "GetClusterNode" {

    Mock Log -MockWith {}

    Context "When connected to a cluster" {

        It "Given valid node - It should get the node" {

            $nodeIP = "10.0.0.2";

            Mock Get-NlbClusterNode -ParameterFilter { $InputObject -Eq $null -And $NodeName -Eq $nodeIP } -MockWith { Return @{} }

            GetClusterNode $nodeIP

            Assert-MockCalled Get-NlbClusterNode -Times 1 -Exactly -Scope It
        }

        It "Given invalid node - It should throw an error" {

            $nodeIP = "10.0.0.2";

            Mock Get-NlbClusterNode -ParameterFilter { $InputObject -Eq $null -And $NodeName -Eq $nodeIP } -MockWith { Return $null }

            {GetClusterNode $nodeIP} | Should -Throw "Node not found."

            Assert-MockCalled Get-NlbClusterNode -Times 1 -Exactly -Scope It
        }
    }
}

Describe "StopClusterNode" {

    Mock Log -MockWith {}

    Context "When connected to a cluster" {

        It "Given no DrainStop - It should stop the node immediately" {

            $nodeIP = "10.0.0.2";
            $node = @{}

            Mock GetClusterNode -ParameterFilter { $NodeName -Eq $nodeIP } -MockWith { Return $node }

            Mock Stop-NlbClusterNode -ParameterFilter { $InputObject -Eq $node -And $Drain -Eq $false -And $DrainStopTimeout -Eq $null } -MockWith {}

            StopClusterNode -NodeName $nodeIP

            Assert-MockCalled Stop-NlbClusterNode -Times 1 -Exactly -Scope It
        }

        It "Given DrainStop and no timeout - It should stop wait until the node completely stops" {

            $nodeIP = "10.0.0.2";
            $node = @{}

            Mock GetClusterNode -ParameterFilter { $NodeName -Eq $nodeIP } -MockWith { Return $node }

            Mock Stop-NlbClusterNode -ParameterFilter { $InputObject -Eq $node -And $Drain -Eq $true -And $DrainStopTimeout -Eq 0 } -MockWith {}

            StopClusterNode -NodeName $nodeIP -Drain $true -DrainStopTimeout 0

            Assert-MockCalled Stop-NlbClusterNode -Times 1 -Exactly -Scope It
        }

        It "Given DrainStop and timeout - It should stop wait until the node completely stops or timeout" {

            $nodeIP = "10.0.0.2";
            $node = @{}
            $timeout = 1;

            Mock GetClusterNode -ParameterFilter { $NodeName -Eq $nodeIP } -MockWith { Return $node }

            Mock Stop-NlbClusterNode -ParameterFilter { $InputObject -Eq $node -And $Drain -Eq $true -And $DrainStopTimeout -Eq $timeout } -MockWith {}

            StopClusterNode -NodeName $nodeIP -Drain $true -DrainStopTimeout $timeout

            Assert-MockCalled Stop-NlbClusterNode -Times 1 -Exactly -Scope It
        }
    }
}

Describe "StartClusterNode" {

    Mock Log -MockWith {}

    Context "When connected to a cluster" {

        It "It should start the node" {

            $nodeIP = "10.0.0.2";
            $node = @{}

            Mock GetClusterNode -ParameterFilter { $NodeName -Eq $nodeIP } -MockWith { Return $node }

            Mock Start-NlbClusterNode -ParameterFilter { $InputObject -Eq $node } -MockWith {}

            StartClusterNode -NodeName $nodeIP

            Assert-MockCalled Start-NlbClusterNode -Times 1 -Exactly -Scope It
        }
    }
}
