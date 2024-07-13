# PowerCfg for PowerShell
## Why?
Because this:  
`
powercfg /setacvalueindex 44cd9e71-a820-4b41-b140-c31bfd6d8d16 533946e9-7bb0-45a1-a491-c2869dc960f7 90bc6708-88e1-4e70-8ec9-dc020b9c6dbc 0
`  
sucks.

### PowerCfg module offers working with names instead of Guids, because...of course.

Isn't this better?
```powershell
Set-PowercfgSetting -PowerScheme Balanced -SubGroup Display -Setting "turn off" -SetAC -Value 0
```
and, **Aliased** + Positional parameters:
```powershell
spcs balanced display "turn off" 0 -setac
```
> ### ✅ Remote Capability
> 
> Using WinRM, can be pointed to remote computers!
> ```powershell
> Get-PowercfgSetting -ComputerName $compName -SubGroup "High Performance"
> ```
---
The PowerCfg module works by dynamically acquiring necessary guids to work with the windows powercfg command under the hood. This allows you to work solely with the human-readable format.
Guids are acquired through simple string parsing matching patterns with Regex. You ask for your custom "Awesome Power Scheme", and the module silently finds the guid for it, then uses it the way Windows' powercfg expects.  
You get the results you want and you never need to see a Guid.

I do my best to follow PowerShell best practices and follow my own rigid standards. Albeit, this is all a work in progress. Ideally, my module:
- Uses custom classes that provides methods matching functionality found in the functions
- Provides expansive help, not to exclude each parameter
- Custom formatting, including all properties as they might relate to the object, yet only showing those that matter most immediately to the user
- Avoiding piping within the functions as much as possible.  
  (You may notice use of `.Where()` rather than ` | Where-Object {}`, for example)
  
And much more... Not to say I'm hitting all of the marks all of the time, yet, but I hope the module delivers an experience indistinguishible from native PowerShell.  

## Try it out: https://www.powershellgallery.com/packages/PowerCfg/0.2.1
```powershell
Install-Module -Name PowerCfg
```

---

> ### 📘 PowerCfg is still young
> Not all of cmd's powercfg switches are covered yet. What is here offers pipeline and remote computer support.
>
> See the function help for examples.

I hope to soon add methods to the custom object types and more functions to cover the variety of switches present in the windows command.
