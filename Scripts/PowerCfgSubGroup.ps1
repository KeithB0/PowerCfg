class PowerCfgSubGroup {
    [string]    $Name
    [Guid]      $Guid
    [PSObject]  $Settings

<# Define the class. Try constructors, properties, or methods. #>
    PowerCfgSubGroup([String]$Name, [Guid]$Guid, [PSObject]$Settings){
        $this.Name = $Name
        $this.Guid = $Guid
        $this.Settings = $Settings
    }

    PowerCfgSubGroup([PSObject]$SubGroup){
        $this.Name = $SubGroup.Name
        $this.Guid = $Subgroup.Guid
        $this.Settings = $SubGroup.Settings
    }
}