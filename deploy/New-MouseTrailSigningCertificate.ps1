#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('EnterpriseCA','SelfSigned')][string]$Mode = 'EnterpriseCA',
    [string]$Template = 'CodeSigning',
    [ValidatePattern('^[a-zA-Z0-9 ._-]+$')][string]$Publisher = 'MouseTrail'
)
$ErrorActionPreference = 'Stop'
if ($Mode -eq 'EnterpriseCA') {
    $request = Get-Certificate -Template $Template -SubjectName "CN=$Publisher" -CertStoreLocation Cert:\CurrentUser\My
    if ($request.Status -ne 'Issued') { throw 'The CA has not issued the certificate. Complete the CA approval before publishing.' }
    $certificate = $request.Certificate
} else {
    $certificate = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=$Publisher Preview" -CertStoreLocation Cert:\CurrentUser\My -KeyAlgorithm RSA -KeyLength 3072 -HashAlgorithm SHA256 -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddYears(1)
    Write-Warning 'This is a test signing identity. Clients must trust it through their normal certificate-management process. The script does not change trust stores.'
}
if (-not $certificate.HasPrivateKey -or $certificate.EnhancedKeyUsageList.ObjectId -notcontains '1.3.6.1.5.5.7.3.3') { throw 'The issued certificate must have a private key and the Code Signing usage.' }
$certificate | Select-Object Subject,Thumbprint,NotAfter
