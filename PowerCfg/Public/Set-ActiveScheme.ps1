<#
.Synopsis
   Sets the specified scheme name to the Active power scheme.
.DESCRIPTION
   Sets entered PowerScheme name to the active one. Can pipe Get-PowercfgSettings with -ComputerName to set on remote computer, or specify -ComputerName inside function.
.EXAMPLE
   Set-ActiveScheme -PowerScheme Balanced

   Sets current power plan to "Balanced", if present.
.EXAMPLE
   Get-PowercfgSettings -ComputerName $ComputerName -List | Set-ActiveScheme "High Performance"

   Sets a targeted computer (requires -List switch) from pipeline to set the active scheme to "High Performance".
.INPUTS
   ComputerName
   PowerScheme
.OUTPUTS
   [PowerCfgPlan]
.NOTES
   Relies on WinRM to use Invoke-Command when targeting remote computers.
.FUNCTIONALITY
   Uses powercfg /s
#>
function Set-ActiveScheme
{
    [CmdletBinding()]
    Param
    (
        [Parameter(
            ValueFromPipelineByPropertyName
        )]
        [Alias("CN")]
        [String]
        $ComputerName,
    
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            Position=0
        )]
        [ValidateNotNullOrEmpty()]
        [PowerCfgPlan]
        $PowerScheme
    )

    Begin
    {
        # Count null powerschemes as each one passes through pipe. If this equals 0 by End{}, than no matching scheme was found.
        # Only necessary for pipeline compatibility.
        [int]$tallyScheme=0
    }
    Process
    {
        # Computername handler first in Process block for pipeline compatibility
        if(!$cfg){
            if($ComputerName){
                Try{
                    $cfg = Invoke-Command $ComputerName {
                        powercfg /l
                    }
                }
                Catch{
                    throw
                }
            }
            Else{
                $cfg = powercfg /l
            }
        }
        # Parse out the heading
        $cfg = $cfg[3..(($cfg.count)-1)]

        # Build out scheme table to translate between names and guids
        $schemeTable = @()
        foreach($scheme in $cfg){
            $null = $scheme -match "\((.+)\)";$name = $Matches[1]
            $null = $scheme -match "\s{1}(\S+\d+\S+)\s{1}";$guid = $Matches[1]

            if($scheme -match "\*$"){$active = $true}
            elseif($scheme -notmatch "\*$"){$active = $false}

            $temp = [PSCustomObject]@{
                Name=$name
                Guid=[Guid]$guid
                Active=[bool]$active
            }
            [PowerCfgPlan]$temp = $temp
            $schemeTable += $temp
            $null = Remove-Variable temp -Force
        }

        <#$Current = $schemeTable.Where({$_.Active}).Name
        if($null -ne $Current -and $PowerScheme -match $Current){
            Write-Warning "Chosen PowerScheme, $Current, is already active."
        }#>
        # Not pipeline compatible

        $selPowerScheme = ($schemeTable.Where({$_.Name -like "*$($PowerScheme.Name)*"}).Guid.Guid)
        if($selPowerScheme.count -gt 1){
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.ArgumentOutOfRangeException]::new(
                        "-PowerScheme",
                        "$($PowerScheme.Name) matches multiple values."
                    ),
                    "PowerScheme.>1",
                    [System.Management.Automation.ErrorCategory]::LimitsExceeded,
                    $PowerScheme
                )
            )
        }

        if($null -ne $selPowerScheme){
            $null = $tallyScheme++

            if($ComputerName){
                Try{
                    Invoke-Command $ComputerName {
                        powercfg /s $using:selPowerScheme
                    }
                    Get-PowercfgSettings -ComputerName $ComputerName -List
                }
                Catch{
                    throw
                }
            }
            Else{
                powercfg /s $selPowerScheme
                Get-PowercfgSettings -List
            }
        }
    }
    End
    {
        # The error if a bad PowerScheme name is entered.
        if($tallyScheme -eq 0){
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.ArgumentException]::new(
                        "$($PowerScheme.Name) not found",
                        "-PowerScheme"
                    ),
                    "PowerScheme.notfound",
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $PowerScheme
                )
            )
        }
    }
}