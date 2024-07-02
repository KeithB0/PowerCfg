<#
.Synopsis
Short description
.DESCRIPTION
Long description
.EXAMPLE
Example of how to use this cmdlet
.EXAMPLE
Another example of how to use this cmdlet
.INPUTS
Inputs to this cmdlet (if any)
.OUTPUTS
Output from this cmdlet (if any)
.NOTES
General notes
.COMPONENT
The component this cmdlet belongs to
.ROLE
The role this cmdlet belongs to
.FUNCTIONALITY
The functionality that best describes this cmdlet
#>
function Set-PowercfgSettings
{
   [CmdletBinding(
      SupportsShouldProcess,
      ConfirmImpact="High",
      DefaultParameterSetName="Manual"
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
      $Force#,

      #[Switch]
      #$PassThru
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
         $cfg = $cfg[3..(($cfg.count)-1)]
      }
   Process
   {
      if($PSCmdlet.ParameterSetName -eq "Manual"){
         # Get PowerScheme
         if(!$PowerScheme){
            $cfg = $cfg.where({$_ -match "(.+)\s{1}\*$"})
         }

         $schemeTable = $null
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
            [PowerCfgPlan]$schemeTable += $temp
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

         if($ComputerName){
            Try{
               $QueryScheme = Invoke-Command $ComputerName {
                  powercfg /q $using:selPowerScheme
               }
            }
            Catch{
               throw
            }
         }
         Else{
            $QueryScheme = powercfg /q $selPowerScheme
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

         # Get SubGroup
         $subgroups = (($QueryScheme) -match "SubGroup GUID: ").TrimStart().Trim()

         if([bool]($subgroups -match $SubGroup)){
            $p_SubGroup = $subgroups -match $SubGroup
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

         # Get GUIDs

         $null = $p_SubGroup[0] -match "\s{1}(\S+\d+\S+)\s{1}";$Groupguid = $Matches[1]
         $null = $p_Setting[0] -match "\s{1}(\S+\d+\S+)\s{1}";$Settingguid = $Matches[1]

         $null = $p_SubGroup[0] -match "\((.+)\)";$Groupname = $Matches[1]
         $null = $p_Setting[0] -match "\((.+)\)";$Settingname = $Matches[1]

         # $selPowerScheme, $Groupguid, $Settingguid
         # Until renamed, these are the vars for Plan, SubGroup, and Setting
         
         $commands = @()

         if($ComputerName){
            $Target = "$ComputerName -> $Groupname->$Settingname"
         }
         else{
            $Target = "$Groupname->$Settingname"
         }

         if($SetAC){
            if(($Force) -or ($pscmdlet.ShouldProcess($Target, "Set AC value to $value"))){
               $commands += {powercfg /setacvalueindex ($selPowerScheme) ($Groupguid) ($Settingguid) $value}
            }
         }
         if($SetDC){
            if(($Force) -or ($PSCmdlet.ShouldProcess($Target, "Set DC value to $value"))){
               $commands += {powercfg /setdcvalueindex ($selPowerScheme) ($Groupguid) ($Settingguid) $value}
            }
         }
         if(!($ComputerName)){
            $commands | ForEach-Object{& $_}
         }
         else{
            Try{
               Invoke-Command -ComputerName $ComputerName {$using:commands | ForEach-Object{& $_}}
            }
            Catch{
               throw
            }
         }
      }


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
         }

         $p_PowerScheme = $p_Setting.Plan
         $p_SubGroup = $p_Setting.SubGroup

         $commands = @()

         if($ComputerName){
            $Target = "$ComputerName -> $($p_SubGroup.Name)->$($p_Setting.Name)"
         }
         else{
            $Target = "$($p_SubGroup.Name)->$($p_Setting.Name)"
         }

         if($SetAC){
            if(($Force) -or ($pscmdlet.ShouldProcess($Target, "Set AC value to $value"))){
               $commands += {powercfg /setacvalueindex ($p_PowerScheme.guid.guid) ($p_SubGroup.guid.guid) ($p_Setting.guid.guid) $value}
            }
         }
         if($SetDC){
            if(($Force) -or ($PSCmdlet.ShouldProcess($Target, "Set DC value to $value"))){
               $commands += {powercfg /setdcvalueindex ($p_PowerScheme.guid.guid) ($p_SubGroup.guid.guid) ($p_Setting.guid.guid) $value}
            }
         }
         if(!($ComputerName)){
            $commands | ForEach-Object{& $_}
         }
         else{
            Try{
               Invoke-Command -ComputerName $ComputerName {$using:commands | ForEach-Object{& $_}}
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