class PowerCfgPlan {
    [string]    $Name
    [Guid]      $Guid
    [Bool]      $Active
    <# Define the class. Try constructors, properties, or methods. #>
    PowerCfgPlan([String]$Name, [Guid]$Guid, [Bool]$Active){
        $this.Name = $Name
        $this.Guid = $Guid
        $this.Active = $Active
    }
    
    PowerCfgPlan([PSObject]$Plan){
        $this.Name = [String]$Plan.Name
        $this.Guid = [Guid]$Plan.Guid
        $this.Active = [Bool]$Plan.Active
    }
}