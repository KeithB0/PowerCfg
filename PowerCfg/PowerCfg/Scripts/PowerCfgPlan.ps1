class PowerCfgPlan {
    [string]    $Name
    [string]    $Description
    [Guid]      $Guid
    [Bool]      $Active
    <# Define the class. Try constructors, properties, or methods. #>
    PowerCfgPlan([String]$Name, [String]$Description, [Guid]$Guid, [Bool]$Active){
        $this.Name = $Name
        $this.Description = $Description
        $this.Guid = $Guid
        $this.Active = $Active
    }
    
    PowerCfgPlan([PSObject]$Plan){
        $this.Name = [String]$Plan.Name
        $this.Description = $Plan.Description
        $this.Guid = [Guid]$Plan.Guid
        $this.Active = [Bool]$Plan.Active
    }

    PowerCfgPlan([String]$PlanName){
        $this.Name = $PlanName
    }
}