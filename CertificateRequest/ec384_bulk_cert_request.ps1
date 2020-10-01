## Bulk Certificate Creation & Export Script
## Script Author: Colby Wallace Sept 2020
## Original Source reference:
## //blog.kloud.com.au/2013/07/30/ssl-san-certificate-request-and-import-from-powershell/
#
#
#----example cli run:  .\ec384_bulk_cert_request.ps1 -csvFile sourcefilepath -IssuingCA CAHostname\CAName -CATemplate certificatetemplatename
#
# Global Parameters Set
#
param (
    #csv file path parameter
    [Parameter(Mandatory=$true)][string]$csvFile,
    #CA server parameter (input format:  CAHostname\CAName)
    [Parameter(Mandatory=$true)][string]$IssuingCA,
    #Certificate Template (input format: us template name [has no spaces], not the template display name)
    [Parameter(Mandatory=$true)][string]$CATemplate
)
#
#
#--- Begin Define Functions ---#
Function New-CertificateRequest {
    param (
        [Parameter(Mandatory=$true)][string]$deviceName,
        [Parameter(Mandatory=$true)][string]$certSvr,
        [Parameter(Mandatory=$true)][string]$certTemplate,
        [Parameter(Mandatory=$false)][string]$ExportPath
    )
 
    ### Define Variables
    $global:CertificateINI = "$deviceName.ini"
    $global:CertificateREQ = "$deviceName.req"
    $global:CertificateRSP = "$deviceName.rsp"
    $global:CertificateCER = "$deviceName.cer"
 
    ### Define Export Location
    if ((Test-Path $ExportLocation) -eq $false){New-Item -Path $ExportLocation -ItemType Directory -Force}
 
    ### INI file generation (ini file needed for certreq to generate certificate request)
    Set-Location $ExportLocation
    New-Item -type file $CertificateINI -force
    #
    Add-Content $CertificateINI '[NewRequest]'
    $temp = 'Subject="' + $SubjectName + '"'
    Add-Content $CertificateINI $temp
    Add-Content $CertificateINI 'FriendlyName="VPN Client Cert"'
    Add-Content $CertificateINI 'Exportable=TRUE'
    Add-Content $CertificateINI 'KeyLength=384'
    Add-Content $CertificateINI 'KeySpec=2'
    Add-Content $CertificateINI 'KeyUsage=0xA0'
    Add-Content $CertificateINI 'KeyAlgorithm=ECDH_secP384r1'
    Add-Content $CertificateINI 'MachineKeySet=TRUE'
    Add-Content $CertificateINI 'ProviderName="Microsoft Software Key Storage Provider"'
    #Add-Content $CertificateINI 'ProviderType=12'
    Add-Content $CertificateINI 'SMIME=FALSE'
    Add-Content $CertificateINI 'RequestType=PKCS10'
     
    #Write-Output $CertificateREQ
    #
    ### Certificate request generation
    if (Test-Path $CertificateREQ) {Remove-Item $CertificateREQ}
    certreq.exe -new $CertificateINI $CertificateREQ
 
    ### Online certificate request and import
    if ($IssuingCA){
        if (Test-Path $CertificateCER) {Remove-Item $CertificateCER}
        if (Test-Path $CertificateRSP) {Remove-Item $CertificateRSP}
        certreq.exe -submit -attrib "CertificateTemplate:$CATemplate" -config $IssuingCA $CertificateREQ $CertificateCER
 
        certreq.exe -accept $CertificateCER
    }
}
Function Export-CertificateRequest {
    param (
        [Parameter(Mandatory=$true)][string]$deviceName,
        [Parameter(Mandatory=$true)][string]$ExportLocation
    )
 
    $Certificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq $SubjectName}
    $CertificateExport = $ExportLocation + '\' + $deviceName + '.pfx'
    Export-PfxCertificate -Cert $Certificate.PSPath -FilePath $CertificateExport -Password $securePW
}
Function Clean-CertificateRequest {
 
    $Certificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq $SubjectName}
 
    if (Test-Path $CertificateREQ) {Remove-Item $CertificateREQ}
    if (Test-Path $CertificateCER) {Remove-Item $CertificateCER}
    if (Test-Path $CertificateRSP) {Remove-Item $CertificateRSP}
    if (Test-Path $CertificateINI) {Remove-Item $CertificateINI}
 
    Remove-Item $certificate.PSPath
 
}
#---End Define Funcitons---#
#
#---Begin Script Run---#
#
#
#--Variables
$devices = Import-Csv -Path $csvFile
$ExportPath = 'C:\data\certRequests\CertExport'
#
foreach ($device in $devices){
    
    $deviceName = $device.subjectName
    $SubjectName = 'CN=' + $deviceName
    $ExportLocation = $ExportPath + '\' + $deviceName
    $devicePW = $deviceName
    $securePW = ConvertTo-SecureString $devicePW -AsPlainText -Force
    #
    New-CertificateRequest `
        -deviceName $deviceName `
        -certSvr $IssuingCA `
        -certTemplate $CATemplate 
 
    Export-CertificateRequest `
        -deviceName $deviceName `
        -ExportLocation $ExportLocation
 
    Clean-CertificateRequest
    #
    
}
#
Write-Output "Generated Certificates Location: $ExportPath"
#
Set-Location C:\data\scripts
#
#---End Script Run---#