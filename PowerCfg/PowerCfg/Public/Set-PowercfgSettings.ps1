<#
.Synopsis
   Sets PowerCfg settings
.DESCRIPTION
   Set setting values to PowerCfg or pipe settings from Get-PowercfgSettings and set values.
.PARAMETER ComputerName
   Target a specified computer. When piping results from Get-PowercfgSettings, the original targeted computer is retained and this parameter is not necessary.
.PARAMETER PowerScheme
   Specify the PowerScheme of which settings to be modified. When not used, the currently active power plan is used by default.
.PARAMETER SubGroup
   Specified SubGroup that holds the settings that can be changed.
.PARAMETER Setting
   The setting to be modified. See Get-PowercfgSettings to see valid ranges and options.
.PARAMETER Value
   Value of which to set the specified setting to.
.PARAMETER SetAC
   Set value to the AC mode. Can be used with SetDC to modify both values.
.PARAMETER SetDC
   Set value to the DC mode. Can be used with SetAC to modify both values.
.PARAMETER Force
   Ignore prompt from ShouldProcess, attempt to complete action silently.
.EXAMPLE
   Set-PowercfgSettings -ComputerName $computername -PowerScheme 'High Performance' -SubGroup display -setting 'Turn off' -SetAC -SetDC -Value 120

   Sets "Turn off display after" from the "Display" SubGroup to 120.
.EXAMPLE
   Get-PowerCfgSettings -SubGroup display -Setting "Display Brightness" | Set-PowerCfgSettings -SetAC -Value 400 -Force

   Gets the "Display Brightness" setting from the "Display" Subgroup and passes it to Set-PowerCfgSettings where it's AC value is set to 400.
.INPUTS
   ComputerName
   PowerScheme
   SubGroup
   Setting
   [PowerCfgSetting]
.OUTPUTS
   [PowerCfgSetting]
.NOTES
   Relies on WinRM to use Invoke-Command when targeting remote computers.
.FUNCTIONALITY
   Configures powercfg
#>
function Set-PowercfgSettings
{
   [CmdletBinding(
      SupportsShouldProcess,
      ConfirmImpact="High",
      DefaultParameterSetName="Manual",
      HelpUri="https://github.com/KeithB0/PowerCfg/wiki/Set%E2%80%90PowercfgSettings"
   )]
   [Alias("spcs")]
   Param
   (
      [Parameter(
         ValueFromPipelineByPropertyName,
         ParameterSetName="Pipeline"
      )]
      [Parameter(
         ValueFromPipeline=$false,
         ParameterSetName="Manual"
      )]
      [ValidateNotNullOrEmpty()]
      [Alias("CN")]
      [String]
      $ComputerName,
      
      [Parameter(
         ParameterSetName="Manual",
         Position=0
      )]
      [String]
      $PowerScheme,

      [Parameter(
         ParameterSetName="Manual",
         Position=1,
         Mandatory
      )]
      [String]
      $SubGroup,

      [Parameter(
         ParameterSetName="Manual",
         Position=2,
         Mandatory
      )]
      [String]
      $Setting,

      [Parameter(
         Mandatory,
         Position=3
      )]
      [int]
      $Value,

      [Parameter(
         DontShow,
         ValueFromPipeline,
         ParameterSetName="Pipeline"
      )]
      [PowerCfgSetting]
      $p_Setting,

      [Switch]
      $SetAC,

      [Switch]
      $SetDC,

      [Switch]
      $Force
   )

   Begin{
      if(!($SetAC -or $SetDC)){
         $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
               [System.ArgumentNullException]::new(
                  "-SetAC, -SetDC",
                  "Setting type not specified. Use one or both."
               ),
               "PowerScheme.TypeSetting",
               [System.Management.Automation.ErrorCategory]::NotSpecified,
               ""
            )
         )
      }
   }
   Process
   {
      # Computername handler first in Process block for pipeline compatibility
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
         Write-Verbose "Queried $ComputerNamee for power schemes"
      }
      Else{
         $cfg = powercfg /l
         $DescList = (gcim Win32_PowerPlan -Namespace root\cimv2\power)
         Write-Verbose "Queried power schemes"
      }
      # Parse out the heading
      $cfg = $cfg[3..(($cfg.count)-1)]

      # Manual entry (no pipeline) requires dedicated string parsing as if we were using Get-PowercfgSetting.
      if($PSCmdlet.ParameterSetName -eq "Manual"){
         # Get PowerScheme
         if(!$PowerScheme){
            $cfg = $cfg.where({$_ -match "(.+)\s{1}\*$"})
            Write-Verbose "No power scheme selected, using currently active scheme"
         }

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
         if(!$PowerScheme){
            $PowerScheme = $schemeTable.Name
         }

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
         if ((!$?) -or ($null -eq $selPowerScheme)) {
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

         Write-Verbose "Using $($schemeTable.Name) for power scheme, acquired guid"

         # Get Power Plan
         if($ComputerName){
            Try{
               $QueryScheme = Invoke-Command $ComputerName {
                  powercfg /q $using:selPowerScheme
               }
            }
            Catch{
               throw
            }
            Write-Verbose "Querying $($schemeTable.Name)'s scheme on $ComputerName"
         }
         Else{
            $QueryScheme = powercfg /q $selPowerScheme
            Write-Verbose "Querying $($schemeTable.Name)"
         }

         # Get SubGroup
         $subgroups = (($QueryScheme) -match "SubGroup GUID: ").TrimStart().Trim()

         # $subgroups being an array doesn't assign matches to $Matches, but instead returns the result.
         # We forced a boolean return and then run it again to collect the string output.
         if([bool]($subgroups -match $SubGroup)){
            $p_SubGroup = $subgroups -match $SubGroup
         }
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
         Write-Verbose "Using subgroup, $p_SubGroup"

         # Get Setting
         $settings = (($QueryScheme) -match "Power Setting Guid: ").TrimStart().Trim()

         if([bool]($settings -match $Setting)){
            Remove-Variable p_Setting -Force
            $p_Setting = $settings -match $Setting
         }
         else{
            $PSCmdlet.ThrowTerminatingError(
               [System.Management.Automation.ErrorRecord]::new(
                  [System.ArgumentException]::new(
                     "$Setting not found",
                     "-Setting"
                  ),
                  "Setting.notfound",
                  [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                  $Setting
               )
            ) # The error for if a bad SubGroup name is specified.
         }
         Write-Verbose "Using setting, $p_Setting"

         # Get GUIDs
         $null = $p_SubGroup[0] -match "\s{1}(\S+\d+\S+)\s{1}";$Groupguid = $Matches[1]
         $null = $p_Setting[0] -match "\s{1}(\S+\d+\S+)\s{1}";$Settingguid = $Matches[1]

         # Get Names
         $null = $p_SubGroup[0] -match "\((.+)\)";$Groupname = $Matches[1]
         $null = $p_Setting[0] -match "\((.+)\)";$Settingname = $Matches[1]

         # $selPowerScheme, $Groupguid, $Settingguid
         # Until renamed, these are the vars for Plan, SubGroup, and Setting
         
         $commands = @()

         if($ComputerName){
            $Target = "$ComputerName -> $Groupname -> $Settingname"
         }
         else{
            $Target = "$Groupname -> $Settingname"
         }

         if($SetAC){
            if(($Force) -or ($pscmdlet.ShouldProcess($Target, "Set AC value to $value"))){
               $commands += {powercfg /setacvalueindex ($selPowerScheme) ($Groupguid) ($Settingguid) $value}
               Write-Verbose "Changing AC value to $value"
            }
         }
         if($SetDC){
            if(($Force) -or ($PSCmdlet.ShouldProcess($Target, "Set DC value to $value"))){
               $commands += {powercfg /setdcvalueindex ($selPowerScheme) ($Groupguid) ($Settingguid) $value}
               Write-Verbose "Changing DC value to $value"
            }
         }

         $PassThru = @{PowerScheme = $PowerScheme;SubGroup = $Groupname;Setting = $Settingname}

         if(!($ComputerName)){
            $commands | ForEach-Object{
               & $_
               Get-PowercfgSettings @PassThru
            }
         }
         else{
            $PassThru += @{ComputerName = $ComputerName}
            Try{
               Invoke-Command -ComputerName $ComputerName {
                  param(
                     $selPowerScheme,
                     $Groupguid,
                     $Settingguid,
                     $Value
                  )
                  if($using:SetDC){
                     & powercfg /setdcvalueindex $selPowerScheme $Groupguid $Settingguid $Value
                  }
                  if($using:SetAC){
                     & powercfg /setacvalueindex $selPowerScheme $Groupguid $Settingguid $Value
                  }
               } -ArgumentList $selPowerScheme,$Groupguid,$Settingguid,$Value
               Get-PowercfgSettings @PassThru
            }
            Catch{
               throw
            }
         }
      }

      # Pipeline entry - where a [PowerCfgSetting] is sent over, it holds all necessary arguments for local execution.
      if($PSCmdlet.ParameterSetName -eq "Pipeline"){
         if($p_Setting.count -gt 1){
            $PSCmdlet.ThrowTerminatingError(
               [System.Management.Automation.ErrorRecord]::new(
                  [System.ArgumentOutOfRangeException]::new(
                     "Multiple Settings Found. Specify One."
                  ),
                  "Setting.>1",
                  [System.Management.Automation.ErrorCategory]::NotSpecified,
                  ""
               )
            )
         } # Currently, not handling multiple settings. Plan to add piping entire subgroups and plans.

         # Breaking up the variable properties into their own vars
         $p_PowerScheme = $p_Setting.Plan
         $p_SubGroup = $p_Setting.SubGroup

         $commands = @()

         if($ComputerName){
            $Target = "$ComputerName -> $($p_SubGroup.Name) -> $($p_Setting.Name)"
         }
         else{
            $Target = "$($p_SubGroup.Name) -> $($p_Setting.Name)"
         }

         if($SetAC){
            if(($Force) -or ($pscmdlet.ShouldProcess($Target, "Set AC value to $value"))){
               $commands += {powercfg /setacvalueindex $p_PowerScheme.guid.guid $p_SubGroup.guid.guid $p_Setting.guid.guid $value}
               Write-Verbose "Setting AC value to $value"
            }
         }
         if($SetDC){
            if(($Force) -or ($PSCmdlet.ShouldProcess($Target, "Set DC value to $value"))){
               $commands += {powercfg /setdcvalueindex $p_PowerScheme.guid.guid $p_SubGroup.guid.guid $p_Setting.guid.guid $value}
               Write-Verbose "Setting DC value to $value"
            }
         }

         $PassThru = @{PowerScheme = $p_PowerScheme.name;SubGroup = $p_SubGroup.name;Setting = $p_Setting.name}

         if(!($ComputerName)){
            $commands | ForEach-Object{
               & $_
               Get-PowercfgSettings @PassThru
            }
         }
         else{
            $PassThru += @{ComputerName = $ComputerName}
            Try{
               Invoke-Command -ComputerName $ComputerName {
                  param(
                     $p_PowerScheme,
                     $p_SubGroup,
                     $p_Setting,
                     $Value
                  )
                  if($using:SetDC){
                     & powercfg /setdcvalueindex $p_PowerScheme $p_SubGroup $p_Setting $Value
                  }
                  if($using:SetAC){
                     & powercfg /setacvalueindex $p_PowerScheme $p_SubGroup $p_Setting $Value
                  }
               } -ArgumentList $p_PowerScheme.guid.guid,$p_SubGroup.guid.guid,$p_Setting.guid.guid,$Value
               Write-Verbose "Sent change of values as follows: AC: $SetAC; DC: $SetDC; Value: $value"
               Get-PowercfgSettings @PassThru
            }
            Catch{
               throw
            }
         }
      }
   }
   End
   {
   }
}