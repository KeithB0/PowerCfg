<#
.Synopsis
   Gets powercfg configuration data with object-oriented output.
.DESCRIPTION
   Can list power schemes, list subgroups of a selected power scheme, and list settings of subgroups as well as their available and current settings.
.PARAMETER List
    List Power Schemes. Can be used with -ComputerName. Produces [PowerCfgPlan] object for piping.
.PARAMETER Name
    Used with -List to show power plans matching the provided name.
.PARAMETER Active
    Used with -List to show only the Active power plan.
.PARAMETER ComputerName
    Target remote computers. Uses Invoke-Command, relies on WinRM.
.PARAMETER PowerScheme
    Pull Subgroups of a specified Power Scheme. The active plan is the default when this parameter is not used. Produces [PowerCfgSubGroup] object for piping.
.PARAMETER SubGroup
    Pull Settings of a specified SubGroup. Shows Current settings and applicable values for use in Set-PowercfgSettings. Produces [PowerCfgSetting] object for piping.
.PARAMETER Setting
    Specifies a single setting in a SubGroup. This is recommended when piping results to Set-PowercfgSettings. Produces a single [PowerCfgSetting].
.EXAMPLE
   Get-PowercfgSettings -List

   Lists power schemes
.EXAMPLE
   Get-PowercfgSettings -PowerScheme Balanced

   Lists SubGroups of the Balanced power scheme.
.EXAMPLE
   Get-PowercfgSettings -ComputerName $computerName -PowerScheme "High Performance" -SubGroup Sleep

   Lists the configuration of the Sleep settings under the High Performance power scheme of a remote computer.
.EXAMPLE
   gpcs -SubGroup Display

   Using the alias to call the function, the active power scheme is defaulted to and the Display subgroup settings are displayed.
.INPUTS
   [Switch]List
   [String]ComputerName
   [String]PowerScheme
   [String]SubGroup
.OUTPUTS
   [Array]
   [Hashtable]
   [PowerCfgSetting]
   [PowerCfgPlan]
   [PowerCfgSubGroup]
.FUNCTIONALITY
    Reads powercfg
#>
function Get-PowercfgSettings {
    [CmdletBinding(
        DefaultParameterSetName="Query",
        HelpUri="https://github.com/KeithB0/PowerCfg/wiki/Get%E2%80%90PowercfgSettings"
    )]
    [Alias("gpcs")]
    param(
        [Parameter(
            ParameterSetName="List"
        )]
        [Switch]
        $List,

        [Parameter(
            ParameterSetName="List",
            Position=0
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [Parameter(
            ParameterSetName="List"
        )]
        [Switch]
        $Active,

        [Parameter(
            ValueFromPipelineByPropertyName
        )]
        [Alias("CN")]
        [String]
        $ComputerName,

        [Parameter(
            ParameterSetName="Query",
            Position=0
        )]
        [String]
        $PowerScheme,

        [Parameter(
            ParameterSetName="Query",
            Position=1
        )]
        [String]
        $SubGroup,

        [Parameter(
                ParameterSetName="Query",
                Position=2
        )]
        [String]
        $Setting
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

        if($PSCmdlet.ParameterSetName -eq 'List'){
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

                $Desc = $DescList.where({$_.ElementName -eq $name}).Description

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
        if($PSCmdlet.ParameterSetName -eq "Query"){
            # Default parameter value gets SubGroup results of currently active scheme
            if(!$PowerScheme){
                $cfg = $cfg.where({$_ -match "(.+)\s{1}\*$"})
                Write-Verbose "Defaulting to active power scheme"
            }
            else{
                $cfg = $cfg.where({$_ -match "$PowerScheme"})
            }
    
            $schemeTable = @()
            foreach($scheme in $cfg){
                $null = $scheme -match "\((.+)\)";$name = $Matches[1]
                $null = $scheme -match "\s{1}(\S+\d+\S+)\s{1}";$guid = $Matches[1]

                $Desc = $Desc.where({$_.ElementName -eq $name}).Description

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

            # Default Parameter behavior:
            # Move the acquired name of the active scheme into the parameter variable so everything can continue smoothly.
            if(!$PowerScheme){
                $PowerScheme = $schemeTable.Name
            }
            Write-Verbose "Using $($schemeTable.Name) power scheme"

            $selPowerScheme = ($schemeTable.Where({$_.Name -like "*$PowerScheme*"}).Guid.Guid)
            if($selPowerScheme.count -gt 1){
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                            [System.ArgumentOutOfRangeException]::new(
                                "-PowerScheme",
                                "$PowerScheme matches multiple values."
                            ),
                            "PowerScheme.>1",
                            [System.Management.Automation.ErrorCategory]::LimitsExceeded,
                            $PowerScheme
                    )
                )
            }
            # The error if a bad PowerScheme name is entered.

            if ($null -eq $selPowerScheme) {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        [System.ArgumentException]::new(
                            "$PowerScheme not found",
                            "-PowerScheme"
                        ),
                        "PowerScheme.notfound",
                        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                        $PowerScheme
                    )
                )
            }
            # Error if no matching PowerScheme is found.

            # Get SubGroup info
            if($ComputerName){
                Try{
                    $QueryScheme = Invoke-Command $ComputerName {
                        powercfg /q $using:selPowerScheme
                    } -ErrorAction Stop
                }
                Catch{
                    throw
                }
                Write-Verbose "Queried $($schemeTable.Name) power scheme on $ComputerName"
            }
            Else{
                $QueryScheme = powercfg /q $selPowerScheme
                if(!$?){
                    throw
                }
                Write-Verbose "Queried $($schemeTable.Name)"
            }

            # Listing subgroups for string parsing.
            $subgroups = (($QueryScheme) -match "SubGroup GUID: ").TrimStart().Trim()

            # Handler for if a SubGroup is being specified.
            if($SubGroup){
                if([bool]($subgroups -match $SubGroup)){
                    $subgroups = $subgroups -match $SubGroup
                }
                # $subgroups being an array doesn't assign matches to $Matches, but instead returns the result.
                # We forced a boolean return and then run it again to collect the string output.
                else{
                    $PSCmdlet.ThrowTerminatingError(
                        [System.Management.Automation.ErrorRecord]::new(
                            [System.ArgumentException]::new(
                                "$SubGroup not found",
                                "-SubGroup"
                            ),
                            "SubGroup.notfound",
                            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                            $SubGroup
                        )
                    ) # The error for if a bad SubGroup name is specified.
                }
            }

            # Diving into the SubGroup items...
            foreach($SubGroupitem in $subgroups){
                $null = $SubGroupitem -match "\((.+)\)";$Groupname = $Matches[1]
                $null = $SubGroupitem -match "\s{1}(\S+\d+\S+)\s{1}";$Groupguid = $Matches[1]

                if($ComputerName){
                    Try{
                        $subgroupQuery = Invoke-Command $ComputerName {
                            powercfg /q $using:selPowerScheme $using:Groupguid
                        } -ErrorAction Stop
                    }
                    Catch{
                        throw
                    }
                }
                Else{
                    $subgroupQuery = powercfg /q $selPowerScheme $Groupguid
                }

                $settings = ($subgroupQuery -match "Power Setting GUID: ").TrimStart().Trim()

                if($Setting){
                    $settings = $settings.Where({$_ -match $Setting})
                }

                $settingsTable=@()
                # We query each Subgroup and handle them individually to build out a table.
                foreach($line in $settings){
                # Grabbing each Setting from the propogated Subgroup to build a nested table.
                    if($line -match "Power Setting Guid: "){
                        $null = $line -match "\((.+)\)";$name = $Matches[1]
                        $null = $line -match "\s{1}(\S+\d+\S+)\s{1}";$guid = $Matches[1]
                    }
                    $OptionsHash = [ordered]@{}
                    $RangeHash = [ordered]@{}
                    $outputCurrent = @{}
                    if($ComputerName){
                        Try{
                            $settingQuery = Invoke-Command $ComputerName {
                                powercfg /q $using:selPowerScheme $using:Groupguid $using:guid
                            } -ErrorAction Stop
                        }
                        Catch{
                            throw
                        }
                    }
                    Else{
                        $settingQuery = powercfg /q $selPowerScheme $Groupguid $guid
                    }

                    # Querying each setting to look at the optional inputs and ranges there are.
                    foreach($settingConfig in $settingQuery){
                    # Multiple Choice settings (Options in output)
                        if($settingConfig -match "Possible Setting Index: (\d+)"){
                            $index = $matches[1] -replace '^0*(?=\d)'
                        }
                        elseif($settingConfig -match "Possible Setting Friendly Name: (.+)"){
                            $OptionsHash[$matches[1]] = $index
                        }
                    }
                    $settingRange = ($settingQuery -match "\w{3}imum Possible Setting: ")

                    foreach($settingConfig in $settingRange){
                    # Minimum/Maximum settings (Range in output)
                        if($settingConfig -match "Minimum Possible Setting: (.+)"){
                            $Min = [UInt32]$Matches[1]
                        }

                        elseif($settingConfig -match "Maximum Possible Setting: (.+)"){
                            $RangeHash[$Min] = [UInt32]$Matches[1]
                        }
                    }

                    $currentSettings = ($settingQuery -match "Current (A|D)C Power Setting Index: ")
                    foreach($settingConfig in $currentSettings){
                    # Current settings on AC and DC
                        if($settingConfig -match "Current AC Power Setting Index: (.+)"){
                            $CurrentAC = $Matches[1]
                            $CurrentDC = $null
                        }
                        elseif($settingConfig -match "Current DC Power Setting Index: (.+)"){
                            $CurrentAC = $null
                            $CurrentDC = $Matches[1]
                        }
                        $outputCurrent.CurrentAC += $CurrentAC
                        $outputCurrent.CurrentDC += $CurrentDC
                    }
                    # Finally, we build our table of settings belonging to the subgroup.
                    #       I realize I could have done an array for the ranges instead of a hash and then converting them
                    #       into an array (like I did with AC & DC), but I already did what I did. Oh well.
                    $temp = [PSCustomObject]@{
                        Name=$name
                        Guid=[Guid]$guid
                        Options=if($OptionsHash.Count -gt 0){$OptionsHash}else{$null}
                        Range=if($RangeHash.Count -gt 0){@($RangeHash.Keys,$RangeHash.Values)}else{$null}
                        CurrentAC = [UInt32]$outputCurrent.CurrentAC
                        CurrentDC = [UInt32]$outputCurrent.CurrentDC
                    }
                    $temp = [PowerCfgSetting]::new($temp)
                    # Build using our custom object
                    if($ComputerName){
                        $temp | Add-Member -MemberType NoteProperty -Name ComputerName -Value $ComputerName
                    }

                    $settingsTable += $temp
                }
                # And finally, we build our table of subgroups with the nested settings.
                # If SubGroup was used, we don't want to loop output of SubGroups.
                $SubGroupOutput = [PSCustomObject]@{
                    Name=$Groupname
                    Guid=[Guid]$Groupguid
                    Settings = $settingsTable
                }

                $SubGroupOutput = [PowerCfgSubGroup]$SubGroupOutput
                $settingsTable | Add-Member -MemberType NoteProperty -Name SubGroup -Value $SubGroupOutput
                $settingsTable | Add-Member -MemberType NoteProperty -Name Plan -Value $schemeTable

                if(!$SubGroup){
                    $SubGroupOutput
                }
            }
            # Outside of the loop, we'll call the one EXPECTED output's Settings' property from the last table.
            if($SubGroup){
                $SubGroupOutput.Settings
            }

        }
    }
    End{}
}