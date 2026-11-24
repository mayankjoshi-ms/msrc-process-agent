[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$')]
    [string] $VMName,

    [ValidateSet('Admin', 'Standard')]
    [string] $Role = 'Admin',

    [string] $CredentialDirectory = (Join-Path $env:LOCALAPPDATA 'USO-MSRC\Credentials')
)

$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT)
{
    throw 'USO MSRC credential retrieval requires Windows DPAPI.'
}

$path = Join-Path $CredentialDirectory "$VMName.$Role.clixml"
if (-not (Test-Path -LiteralPath $path -PathType Leaf))
{
    throw [System.IO.FileNotFoundException]::new(
        "No protected $Role credential is available for VM '$VMName'. Provision it through a secure credential prompt.",
        $path)
}

$credential = Import-Clixml -LiteralPath $path -ErrorAction Stop
if ($credential -isnot [System.Management.Automation.PSCredential] -or
    [string]::IsNullOrWhiteSpace($credential.UserName))
{
    throw "The protected credential for VM '$VMName' is invalid."
}

$credential
