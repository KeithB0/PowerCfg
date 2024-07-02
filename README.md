# PowerCfg for PowerShell
## Why?
Because this:
```cmd
powercfg /setacvalueindex 44cd9e71-a820-4b41-b140-c31bfd6d8d16 533946e9-7bb0-45a1-a491-c2869dc960f7 90bc6708-88e1-4e70-8ec9-dc020b9c6dbc 0
```
sucks.

PowerCfg module offers working with names instead of Guids, because...of course.

Isn't this better?
```powershell
Set-PowercfgSetting -PowerScheme Balanced -SubGroup Display -Setting "turn off" -SetAC -Value 0
```
and, **Aliased**:
```powershell
spcs balanced display "turn off" 0 -setac
```
---
> ### ✅ Remote Capability
> 
> Using WinRM, can be pointed to remote computers!
> ```powershell
> Get-PowercfgSetting -ComputerName $compName -SubGroup "High Performance"
> ```

Try it out: https://www.powershellgallery.com/packages/PowerCfg/
```powershell
Install-Module -Name PowerCfg
```

---

> ### 📘 PowerCfg is young
> It currently only has Get and Set, but with pipeline compatibility. See the function help for examples.

I hope to soon add methods to the custom object types and more functions to cover the variety of switches present in the windows command.
