<#
.Synopsis
   Gets powercfg configuration data with object-oriented output.
.DESCRIPTION
   Can list power schemes, list subgroups of a selected power scheme, and list settings of subgroups as well as their available and current settings.
.PARAMETER Name
    Used with -List to show power plans matching the provided name.
.PARAMETER Active
    Used with -List to show only the Active power plan.
.PARAMETER ComputerName
    Target remote computers. Uses Invoke-Command, relies on WinRM.
.INPUTS
   [String]Name
   [Switch]Active
   [String]ComputerName
.OUTPUTS
   [PowerCfgPlan]
.FUNCTIONALITY
    Reads powercfg
#>
function Get-PowercfgScheme {
    [CmdletBinding(
        HelpUri="https://github.com/KeithB0/PowerCfg/wiki/Get%E2%80%90PowercfgSettings"
    )]
    param(
        [Parameter(
            
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [Parameter(
            
        )]
        [Switch]
        $Active,

        [Parameter(
            ValueFromPipelineByPropertyName
        )]
        [Alias("CN")]
        [String]
        $ComputerName
    )
    Begin{}
    Process{
        # Handle computername first outside of begin block in case it gets piped in
        if($ComputerName){
            Try{
                $cfg = Invoke-Command $ComputerName {
                    powercfg /l
                } -ErrorAction Stop
                $DescList = Invoke-Command $ComputerName {
                    (gcim Win32_PowerPlan -Namespace root\cimv2\power)
                } -ErrorAction SilentlyContinue
                Write-Verbose "Connected to $ComputerName"
            }
            Catch [Microsoft.Management.Infrastructure.CimException]{
                $writeError = @{
                    Exception = [Microsoft.Management.Infrastructure.CimException]::new("$($Error[0].Exception.Message)")
                    Category = $Error[0].CategoryInfo.Category
                    CategoryActivity = "$($Error[0].CategoryInfo.Activity)"
                    CategoryReason = "$($Error[0].CategoryInfo.Reason)"
                    CategoryTargetName = "$($Error[0].CategoryInfo.TargetName)"
                    CategoryTargetType = "$($Error[0].CategoryInfo.TargetType)"
                }
                Write-Error @writeError
            }
            Catch{
                throw
            }
        }
        Else{
            Try{
                $cfg = powercfg /l
                $DescList = (gcim Win32_PowerPlan -Namespace root\cimv2\power -ErrorAction Stop)
            }
            Catch [Microsoft.Management.Infrastructure.CimException]{
                $writeError = @{
                    Exception = [Microsoft.Management.Infrastructure.CimException]::new("$($Error[0].Exception.Message)")
                    Category = $Error[0].CategoryInfo.Category
                    CategoryActivity = "$($Error[0].CategoryInfo.Activity)"
                    CategoryReason = "$($Error[0].CategoryInfo.Reason)"
                    CategoryTargetName = "$($Error[0].CategoryInfo.TargetName)"
                    CategoryTargetType = "$($Error[0].CategoryInfo.TargetType)"
                }
                Write-Error @writeError
            }
            Catch{
                throw
            }
            Write-Verbose "Queried powercfg"
        }
        $cfg = $cfg[3..(($cfg.count)-1)]

        if($Name){
            $cfg = $cfg.Where({$_ -match $Name})
            if($null -eq $cfg){
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                            [System.ArgumentNullException]::new(
                                "-Name",
                                "$Name has no matches."
                            ),
                            "PowerScheme.Null",
                            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                            $Name
                    )
                )
            }
            Write-Verbose "Filtering list to match $Name"
        }
        if($Active){
            $cfg = $cfg.where({$_ -match "(.+)\s{1}\*$"})
            Write-Verbose "Filtering list to Active scheme"
        }
        foreach($plan in $cfg){
            $null = $plan -match "\((.+)\)";$name = $Matches[1]
            $null = $plan -match "\s{1}(\S+\d+\S+)\s{1}";$guid = $Matches[1]

            $Desc = (Where-Object -InputObject $DescList -FilterScript {$_.ElementName -eq $name}).Description

            if($plan -match "\*$"){$temp = $true}
            elseif($plan -notmatch "\*$"){$temp = $false}

            $plan = [PSCustomObject]@{
                Name=$name
                Description=$Desc
                Guid=[Guid]$guid
                Active=[bool]$temp
            }
            $plan = [PowerCfgPlan]$plan
            if($ComputerName){
                $plan | Add-Member -MemberType NoteProperty -Name ComputerName -Value $ComputerName
            }
            $plan
            # Seeems redundant, but we need to save $plan with the correct object type for appending to
            # settings hidden property for easy pipeline usage.
        }
    }
    End{}
}