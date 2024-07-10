<#
.Synopsis
   Modifies, duplicates, deletes, or changes the power plan.
.DESCRIPTION
   Parameter sets offer renaming a power plan, duplicating it (duplicates are appended with "-Copy"), deleting a power plan, or setting the active power plan. Can pipe Get-PowercfgSettings with -ComputerName to set on remote computer, or specify -ComputerName inside function.
.EXAMPLE
   Set-PowercfgScheme -PowerScheme Balanced -Active

   Sets current power plan to "Balanced", if present.
.EXAMPLE
   Get-PowercfgSettings -ComputerName $ComputerName -List | Set-PowercfgScheme "High Performance" -Active

   Sets a targeted computer (requires -List switch) from pipeline to set the active scheme to "High Performance".
.EXAMPLE
    Get-PowercfgSettings -ComputerName $ComputerName -List -Name "High Performance" | Set-PowercfgScheme -Active

    Similar to the previous example, but the power scheme is specified to the left of the pipe. This allows Get-PowercfgSettings to select a single power plan and pipe one object to Set-PowercfgScheme to set as the active plan.
.EXAMPLE
    Set-PowercfgScheme -ComputerName $ComputerName -PowerScheme Balanced -Duplicate

    Duplicates the "Balanced" power plan. New name will be called "Balanced-Copy"
.EXAMPLE
    Set-PowercfgScheme -PowerScheme "Power Saving" -Rename "Low Power"

    Renames "Power Saving" power plan to "Low Power"
.PARAMETER ComputerName
    Target a remote computer. Uses Invoke-Command and relies on WinRM
.PARAMETER PowerScheme
    Name of power plan to target for selected action
.PARAMETER Active
    Set the power plan as the active plan
.PARAMETER Delete
    Deletes the selected power plan
.PARAMETER Duplicate
    Duplicates the selected power plan. Copies will be named similarly, with "-Copy" appended to it.
.PARAMETER Rename
    Renames a selected PowerScheme
.PARAMETER Description
    Optional. Set a description for a PowerScheme when renaming it.
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
function Set-PowercfgScheme
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
        $PowerScheme,

        [Parameter(
            ParameterSetName="Active"
        )]
        [Switch]
        $Active,

        [Parameter(
            ParameterSetName="Delete"
        )]
        [Switch]
        $Delete,

        [Parameter(
            ParameterSetName="Duplicate"
        )]
        [Switch]
        $Duplicate,

        [Parameter(
            ParameterSetName="Rename"
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Rename,

        [Parameter(
            ParameterSetName="Rename"
        )]
        [String]
        $Description
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
        ### NOT PIPELINE COMPATIBLE ###

        if($schemeTable.Guid.Guid -contains $PowerScheme.Guid.Guid){
            $selPowerScheme = $PowerScheme.Guid.Guid
        }
        else{
            $selPowerScheme = ($schemeTable.Where({$_.Name -like "*$($PowerScheme.Name)*"}).Guid.Guid)
        }

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

            # Force PowerScheme name to match exactly
            $PowerScheme = $schemeTable.Name | Where-Object {$_ -match $PowerScheme.Name}

            if($PSCmdlet.ParameterSetName -eq "Active"){

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

            if($PSCmdlet.ParameterSetName -eq "Delete"){

                if($ComputerName){
                    Try{
                        Invoke-Command $ComputerName {
                            powercfg /d $using:selPowerScheme
                        }
                        Get-PowercfgSettings -ComputerName $ComputerName -List
                    }
                    Catch{
                        throw
                    }
                }
                Else{
                    powercfg /d $selPowerScheme
                    Get-PowercfgSettings -List
                }

            }

            if($PSCmdlet.ParameterSetName -eq "Duplicate"){

                if($ComputerName){
                    Try{
                        Invoke-Command $ComputerName {
                            $null = powercfg /duplicatescheme $using:selPowerScheme
                        }
                        $NewList = Get-PowercfgSettings -ComputerName $ComputerName -List
                        Invoke-Command $ComputerName {
                            $null = powercfg /changename (Compare-Object $using:schemeTable.Guid.Guid $using:NewList.Guid.Guid).InputObject ("$($using:PowerScheme)-Copy")
                        }
                        Get-PowercfgSettings -ComputerName $ComputerName -List
                    }
                    Catch{
                        throw
                    }
                }
                Else{
                    $null = powercfg /duplicatescheme $selPowerScheme
                    $NewList = Get-PowercfgSettings -List
                    powercfg /changename (Compare-Object $schemeTable.Guid.Guid $NewList.Guid.Guid).InputObject ("$($PowerScheme)-Copy")
                    Get-PowercfgSettings -List
                }

            }

            if($PSCmdlet.ParameterSetName -eq "Rename"){
                # Look into splatting this, instead
                if($ComputerName){
                    Try{
                        if(!($Description)){
                            Invoke-Command $ComputerName {
                                powercfg /changename $using:selPowerScheme $Rename
                            }
                        }
                        else{
                            Invoke-Command $ComputerName {
                                powercfg /changename $using:selPowerScheme $Rename $Description
                            }
                        }
                        Get-PowercfgSettings -ComputerName $ComputerName -List
                    }
                    Catch{
                        throw
                    }
                }
                Else{
                    if(!($Description)){
                        powercfg /changename $selPowerScheme $Rename
                    }
                    else{
                        powercfg /changename $selPowerScheme $Rename $Description
                    }
                    Get-PowercfgSettings -List
                }

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