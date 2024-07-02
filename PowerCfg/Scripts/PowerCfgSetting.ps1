class PowerCfgSetting {
            [string]    $CurrentAC
            [string]    $CurrentDC
            [Guid]      $Guid
            [string]    $Name
            [object]    $Options
            [object[]]  $Range
    <# Define the class. Try constructors, properties, or methods. #>
    PowerCfgSetting([PSCustomObject]$Settings){
        $this.CurrentAC = $Settings.CurrentAC
        $this.CurrentDC = $Settings.CurrentDC
        $this.Guid = $Settings.Guid
        $this.Name = $Settings.Name
        $this.Options = $Settings.Options
        $this.Range = $Settings.Range
    }

    [array] CurrentSettings(){
        return @{AC = $this.CurrentAC;DC = $this.CurrentDC}
    }
}