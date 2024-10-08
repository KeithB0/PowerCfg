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
            ValueFromPipelineByPropertyName
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
            ParameterSetName="Rename",
            Mandatory
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Rename,

        [Parameter(
            ParameterSetName="Rename",
            Position=1
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
                    } -ErrorAction Stop
                    $DescList = Invoke-Command $ComputerName {
                        (gcim Win32_PowerPlan -Namespace root\cimv2\power)
                    } -ErrorAction SilentlyContinue
                }
                Catch{
                    throw
                }
                Write-Verbose "Queried scheme list on $ComputerName"
            }
            Else{
                $cfg = powercfg /l
                $DescList = (gcim Win32_PowerPlan -Namespace root\cimv2\power)
                Write-Verbose "Queried scheme list"
            }
        }
        # Parse out the heading
        $cfg = $cfg[3..(($cfg.count)-1)]

        # Build out scheme table to translate between names and guids
        $schemeTable = @()
        foreach($scheme in $cfg){
            $null = $scheme -match "\((.+)\)";$name = $Matches[1]
            $null = $scheme -match "\s{1}(\S+\d+\S+)\s{1}";$guid = $Matches[1]

            $Desc = $DescList.where({$_.ElementName -eq $name}).Description

            if($scheme -match "\*$"){$active = $true}
            elseif($scheme -notmatch "\*$"){$active = $false}

            $temp = [PSCustomObject]@{
                Name=$name
                Description=$Desc
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
            Write-Verbose "Acquired guid from pipeline"
        }
        else{
            $selPowerScheme = ($schemeTable.Where({$_.Name -like "*$($PowerScheme.Name)*"}).Guid.Guid)
        } # Should check for an exact match and prioritize over matches, in cases where you want to set "Balanced" to active, but "Balanced-Copy" is an additional match

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
            $PowerSchemeName = $schemeTable.Name | Where-Object {$_ -match $PowerScheme.Name}
            Write-Verbose "Determined power scheme, $PowerSchemeName, and acquired guid"

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
                    Write-Verbose "Set active scheme on $ComputerName"
                }
                Else{
                    powercfg /s $selPowerScheme
                    Write-Verbose "Set active scheme"
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
                    Write-Verbose "Deleted scheme from $ComputerName"
                }
                Else{
                    powercfg /d $selPowerScheme
                    Write-Verbose "Deleted scheme"
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
                            $null = powercfg /changename (Compare-Object $using:schemeTable.Guid.Guid $using:NewList.Guid.Guid).InputObject ("$($using:PowerSchemeName)-Copy")
                        }
                        Get-PowercfgSettings -ComputerName $ComputerName -List
                    }
                    Catch{
                        throw
                    }
                    Write-Verbose "Duplicated scheme on $ComputerName"
                }
                Else{
                    $null = powercfg /duplicatescheme $selPowerScheme
                    $NewList = Get-PowercfgSettings -List
                    powercfg /changename (Compare-Object $schemeTable.Guid.Guid $NewList.Guid.Guid).InputObject ("$($PowerSchemeName)-Copy")
                    Write-Verbose "Duplicated scheme"
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
                    Write-Verbose "Renamed scheme on $ComputerName"
                }
                Else{
                    if(!($Description)){
                        powercfg /changename $selPowerScheme $Rename
                    }
                    else{
                        powercfg /changename $selPowerScheme $Rename $Description
                    }
                    Write-Verbose "Duplicated scheme"
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