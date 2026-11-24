$ErrorActionPreference = 'Stop'
$scripts = Split-Path $PSScriptRoot -Parent
$getCredential = Join-Path $scripts 'Get-UsoMsrcCredential.ps1'
$setCredential = Join-Path $scripts 'Set-UsoMsrcCredential.ps1'
$directory = Join-Path ([System.IO.Path]::GetTempPath()) ("uso-msrc-credentials-test-" + [guid]::NewGuid())
$secret = [guid]::NewGuid().ToString()
$credential = [System.Management.Automation.PSCredential]::new(
    'validation-user',
    (ConvertTo-SecureString -String $secret -AsPlainText -Force))

function Assert-Throws
{
    param([scriptblock] $Action, [string] $MessagePattern)

    try
    {
        & $Action
    }
    catch
    {
        if ($_.Exception.Message -notmatch $MessagePattern)
        {
            throw
        }
        return
    }
    throw 'Expected an explicit failure.'
}

try
{
    & $setCredential -VMName ValidationVM -Credential $credential -CredentialDirectory $directory
    $actual = & $getCredential -VMName ValidationVM -CredentialDirectory $directory
    if ($actual.UserName -ne $credential.UserName -or
        $actual.GetNetworkCredential().Password -cne $secret)
    {
        throw 'Protected credential round trip failed.'
    }
    $xml = Get-Content -LiteralPath (Join-Path $directory 'ValidationVM.Admin.clixml') -Raw
    if ($xml.Contains($secret))
    {
        throw 'Credential export contains plaintext password material.'
    }

    Assert-Throws {
        & $getCredential -VMName MissingVM -CredentialDirectory $directory
    } 'No protected'
    Assert-Throws {
        & $getCredential -VMName ValidationVM -Role Standard -CredentialDirectory $directory
    } 'No protected'
    Assert-Throws {
        & $getCredential -VMName '..\ValidationVM' -CredentialDirectory $directory
    } 'ValidatePattern|validation pattern|cannot validate'
    Assert-Throws {
        & $setCredential -VMName ValidationVM -Credential $credential -CredentialDirectory $directory
    } 'already exists'

    'not-a-credential' | Export-Clixml -LiteralPath (Join-Path $directory 'InvalidVM.Admin.clixml')
    Assert-Throws {
        & $getCredential -VMName InvalidVM -CredentialDirectory $directory
    } 'is invalid'

    $empty = [System.Management.Automation.PSCredential]::new(
        'validation-standard',
        [securestring]::new())
    & $setCredential -VMName ValidationVM -Role Standard -Credential $empty -CredentialDirectory $directory
    $standard = & $getCredential -VMName ValidationVM -Role Standard -CredentialDirectory $directory
    if ($standard.UserName -ne $empty.UserName -or $standard.Password.Length -ne 0)
    {
        throw 'Standard-user credential round trip failed.'
    }

    & $setCredential -VMName ValidationVM -Credential $empty -CredentialDirectory $directory -Replace
    $replacement = & $getCredential -VMName ValidationVM -CredentialDirectory $directory
    if ($replacement.UserName -ne $empty.UserName)
    {
        throw 'Explicit credential replacement failed.'
    }
    'Credential helper tests passed.'
}
finally
{
    foreach ($name in @('ValidationVM.Admin.clixml', 'ValidationVM.Standard.clixml', 'InvalidVM.Admin.clixml'))
    {
        $path = Join-Path $directory $name
        if (Test-Path -LiteralPath $path)
        {
            Remove-Item -LiteralPath $path
        }
    }
    if (Test-Path -LiteralPath $directory)
    {
        Remove-Item -LiteralPath $directory
    }
}
