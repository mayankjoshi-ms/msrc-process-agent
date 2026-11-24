[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$')]
    [string] $VMName,

    [ValidateSet('Admin', 'Standard')]
    [string] $Role = 'Admin',

    [System.Management.Automation.PSCredential] $Credential,

    [string] $CredentialDirectory = (Join-Path $env:LOCALAPPDATA 'USO-MSRC\Credentials'),

    [switch] $Replace
)

$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT)
{
    throw 'USO MSRC credential storage requires Windows DPAPI.'
}

$path = Join-Path $CredentialDirectory "$VMName.$Role.clixml"
if ((Test-Path -LiteralPath $path) -and -not $Replace)
{
    throw "A protected $Role credential already exists for VM '$VMName'. Use -Replace only after approving its replacement."
}

if ($null -eq $Credential)
{
    $Credential = Get-Credential -Message "Enter the $Role credential for VM '$VMName' securely."
}
if ($null -eq $Credential -or [string]::IsNullOrWhiteSpace($Credential.UserName))
{
    throw 'No valid credential was provided; nothing was stored.'
}

if (-not (Test-Path -LiteralPath $CredentialDirectory -PathType Container))
{
    $null = New-Item -ItemType Directory -Path $CredentialDirectory
}

$security = [System.Security.AccessControl.DirectorySecurity]::new()
$security.SetAccessRuleProtection($true, $false)
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$system = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
foreach ($identity in @($user, $system))
{
    $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $identity,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow)
    $security.AddAccessRule($rule)
}
Set-Acl -LiteralPath $CredentialDirectory -AclObject $security

if ($Replace)
{
    $Credential | Export-Clixml -LiteralPath $path -Force
}
else
{
    $Credential | Export-Clixml -LiteralPath $path -NoClobber
}
