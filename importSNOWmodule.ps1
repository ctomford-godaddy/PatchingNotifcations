Function Import-GDModule(){

    [CmdLetBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Module
    )

    # Step 1: Check if ENGCO repository is installed. If not, install it.
    # Step 2: Check if module is imported.  It typically will not be if running script for first time, or through Jenkins
    # Step 3: Check if module is installed. Installed means it's on the local system (but may not be imported)
    # Step 4: Check in the ENGCO repository.
	
    if(-not (Get-PSRepository -name EngCo -ErrorAction SilentlyContinue)){
        Write-Output "Register-PSRepository -Name EngCo ..."
        
        Register-PSRepository -Name EngCo `
        -SourceLocation https://co.nuget.prod.int.godaddy.com/Powershell/nuget/ `
        -PublishLocation https://co.nuget.prod.int.godaddy.com/Powershell/nuget/ `
        -InstallationPolicy Trusted
    }

    $ImportedModule = Get-Module -name $Module -ErrorAction SilentlyContinue
    $InstalledModule = Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue
    $ENGCOModule = Find-Module -Repository ENGCO -name $Module -ErrorAction SilentlyContinue

    Write-Output "Module Versions: `"$Module`""
    Write-Output "Pre - ENGCO = `"$([System.Version]$ENGCOModule.Version)`""
    Write-Output "Pre - Installed = `"$([System.Version]$InstalledModule.Version)`""
    Write-Output "Pre - Imported = `"$([System.Version]$ImportedModule.Version)`""

    # Check if Module is Installed
    if($InstalledModule){

        # Check if the installed module is an old version
        if(([System.Version]$InstalledModule.Version -lt [System.Version]$ENGCOModule.Version) -and `
        $([System.Version]$InstalledModule.Version).Major -eq $([System.Version]$ENGCOModule.Version).Major){
            Write-Output "Uninstalling old version of module"
            Write-Output "`$InstalledModule | Uninstall-Module"
            $InstalledModule | Uninstall-Module
            Write-Output "Module is not installed. Install it..."
            Write-Output "Find-Module -Repository ENGCO -name $Module | Install-Module -allowclobber -confirm:$false"
            Find-Module -Repository ENGCO -name $Module | Install-Module -allowclobber -confirm:$false
         }

     }else{ # Module is not installed. Install it...

        Write-Output "Module is not installed. Install it..."
        Write-Output "Find-Module -Repository ENGCO -name $Module | Install-Module -allowclobber -confirm:$false"
        Find-Module -Repository ENGCO -name $Module | Install-Module -allowclobber -confirm:$false

        Write-Output "Remove-Module -Name $Module"
        Remove-Module -Name $Module -ErrorAction SilentlyContinue
        Write-Output "Import-Module -Name $Module"
        Import-Module -name $Module 

     }
 
    #  Check if the module is imported
    if(-not $ImportedModule){

        Write-Output "Module not imported: Importing it..."
        Write-Output "Import-Module -name $Module"
        Import-Module -name $Module

    }

    # Perform some checks if the module still isn't imported.
    if(-not (Get-Module -name $Module)){

        Write-Host "`$env:PsModulePath"
        $env:PsModulePath
        Write-Output "Get-PSRepository"
        Get-PSRepository

    }

    $ImportedModule = Get-Module -name $Module
    $InstalledModule = Get-InstalledModule -Name $Module

    Write-Output "Module Versions: `"$Module`""
    Write-Output "Post - ENGCO = `"$([System.Version]$ENGCOModule.Version)`""
    Write-Output "Post - Installed = `"$([System.Version]$InstalledModule.Version)`""
    Write-Output "Post - Imported = `"$([System.Version]$ImportedModule.Version)`""
}

If(-Not (Get-Module GoDaddy.Snow -ListAvailable)){
  Try{ Write-Output "Importing GDModule GoDaddy.Snow"; Import-GDModule GoDaddy.Snow }
  Catch{ Write-Output "GoDaddy.Snow module didn't work."}
}

