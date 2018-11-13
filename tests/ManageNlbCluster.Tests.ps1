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

    Context "When stopping the node" {
        
        Mock Get-VstsInput -ParameterFilter { $Name -Eq "Command" } -MockWith { return "StopClusterNode" }

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
            Mock StopClusterNode -ParameterFilter { $nodeName -Eq $nodeIP -And $drainStop -Eq $drain -And $drainStopTimeout -Eq $timeout } -MockWith {}

            Main

            Assert-MockCalled Get-VstsInput -Times 1 -Exactly -Scope It -ParameterFilter { $Name -Eq "Command" }
            Assert-MockCalled Get-VstsInput -Times 1 -Exactly -Scope It -ParameterFilter { $Name -Eq "DrainStopTimeout" }
            Assert-MockCalled StopClusterNode -Times 1 -Exactly -Scope It -ParameterFilter { $nodeName -Eq $nodeIP -And [System.Object]::Equals($drainStopTimeout, $timeout) }
        }
    }

    Context "When starting the node" {

        Mock Get-VstsInput -ParameterFilter { $Name -Eq "Command" } -MockWith { return "StartClusterNode" }

        It "It should call StartClusterNode" {

            $nodeIP = "10.0.0.2";

            Mock Get-VstsInput -ParameterFilter { $Name -Eq "NodeName" } -MockWith { return $nodeIP }
            Mock StartClusterNode -ParameterFilter { $nodeName -Eq $nodeIP } -MockWith {}

            Main

            Assert-MockCalled Get-VstsInput -Times 1 -Exactly -Scope It -ParameterFilter { $Name -Eq "Command" }
            Assert-MockCalled StartClusterNode -Times 1 -Exactly -Scope It -ParameterFilter { $nodeName -Eq $nodeIP }
        }
    }

    Context "When supplying invalid arguments" {

        It "Given invalid Command - It should throw an exception" {
        
            $command = "InvalidCommand";

            Mock Get-VstsInput -ParameterFilter { $Name -Eq "Command" } -MockWith { return $command }
                
            {Main} | Should -Throw "Command not found. ($command)"
        }

        It "Given DrainStopTimeout -Lt 0 - It should throw an exception" {
        
            $nodeIP = "10.0.0.2";
            $drain = $true;
            $timeout = -1;

            Mock Get-VstsInput -ParameterFilter { $Name -Eq "Command" } -MockWith { return "StopClusterNode" }
            Mock Get-VstsInput -ParameterFilter { $Name -Eq "NodeName" } -MockWith { return $nodeIP }
            Mock Get-VstsInput -ParameterFilter { $Name -Eq "DrainStop" } -MockWith { return $drain }
            Mock Get-VstsInput -ParameterFilter { $Name -Eq "DrainStopTimeout" } -MockWith { return $timeout }
                
            {Main} | Should -Throw "Drain timeout must be greater than or equal to 0."
        }
    }
}

Describe "StopClusterNode" {

    Mock Log -MockWith {}

    Context "When connected to a cluster" {

        It "Given no DrainStop - It should stop the node immediately" {

            $nodeIP = "10.0.0.2";

            Mock Stop-NlbClusterNode -ParameterFilter { $InputObject -Eq $node -And $Drain -Eq $false -And $DrainStopTimeout -Eq $null } -MockWith {}

            StopClusterNode -NodeName $nodeIP

            Assert-MockCalled Stop-NlbClusterNode -Times 1 -Exactly -Scope It
        }

        It "Given DrainStop and no timeout - It should stop wait until the node completely stops" {

            $nodeIP = "10.0.0.2";

            Mock Stop-NlbClusterNode -ParameterFilter { $InputObject -Eq $node -And $Drain -Eq $true -And $DrainStopTimeout -Eq 0 } -MockWith {}

            StopClusterNode -NodeName $nodeIP -Drain $true -DrainStopTimeout 0

            Assert-MockCalled Stop-NlbClusterNode -Times 1 -Exactly -Scope It
        }

        It "Given DrainStop and timeout - It should stop wait until the node completely stops or timeout" {

            $nodeIP = "10.0.0.2";
            $timeout = 1;

            Mock Stop-NlbClusterNode -ParameterFilter { $Drain -Eq $true -And $DrainStopTimeout -Eq $timeout } -MockWith {}

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

            Mock Start-NlbClusterNode -ParameterFilter { $InputObject -Eq $node } -MockWith {}

            StartClusterNode -NodeName $nodeIP

            Assert-MockCalled Start-NlbClusterNode -Times 1 -Exactly -Scope It
        }
    }
}
