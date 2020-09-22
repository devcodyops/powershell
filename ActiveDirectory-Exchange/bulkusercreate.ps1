#-----Declare Variables-----#
#
#All environment specific variables are defined here at the top, edit them as necessary to fit your environment
#
#
#Filepath for prepared csv file
$csvFile = "c:\data\acctRequests\script-test.csv"
#exchange target database name
$exDB = "desired exchange database to create mailboxes in"
# exchange server uri for remote exchange shell command
$exSvrUri = "http://exchangesvr-fqdn/PowerShell/"
# destination OU distinguised name
$destOU  = "Destination OU where accounts are created"
#temp password to set on user account
$tempPwd = "Desired first logon password"
#domain controller to run ad commands on
$domainDC = "domaincontroller-fqdn"
#domain security group to add users to default vdi entitlement
$vdiSecGroup = "domain security group for vdi entitlements"
#domain name
$domain = "domain name for user upn"
#
#------End Declared Variables----#
#
#
#---Begin Script---#
#
#-----Prompt for Domain credentials-----#
$userCreds = Get-Credential
#
#-----Setup PSSession to you needed exchange server-----#
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $exSvrUri -Authentication Kerberos -Credential $userCreds
#
Import-PSSession $Session
#
#-----Set initial user password as secure string-----#
#
$securePassword = ConvertTo-SecureString $tempPwd -AsPlainText -Force
#
#-----Ingest CSV file and create user account with mailbox----#
#---------------Configure database, organizational unit and userprincipalname flags for your environment specifics in the declared variables at top of script
Import-CSV $csvFile | ForEach {New-Mailbox -Alias $_.alias -Name $_.name -Database $exDB -OrganizationalUnit $destOU -Password $securePassword -UserPrincipalName ($_.alias+"@$domain")}
#
#----Disconnect exchange PSSession----#
Remove-PSSession $Session
#
#----Creat Temp PSDrive mapping and copy csv file to dc----#
#-----------Configure Root flag to your desired domaincontroller and folder path
New-PSDrive -name dcpsdrive -PSProvider FileSystem -Root "\\$domainDC\c$\data\acctRequests" -Credential $userCreds
Copy-Item -Path $csvFile -Destination dcpsdrive:
#----Remove Temp drive mapping----#
Remove-PSDrive -name dcpsdrive
#
Import-module ActiveDirectory
#
#----Invoke remote powershell commands on dc to modify users-----#
#-------configure computername flag to same domain controller you copied your csv file to using domainDC variable defined at script start
Invoke-Command -ComputerName $domainDC -Credential $usercreds -ArgumentList ($csvFile, $domainDC, $vdiSecGroup) -ScriptBlock {
    param($csvFile, $domainDC, $vdiSecGroup)
    #--------Configure server flag to your needed domain controller using declared domainDc variable at top of script
    Import-CSV $csvFile | ForEach {Set-ADUser -Server "$domainDC" -Identity $_.alias -Office $_.office -Description $_.office -ChangePasswordAtLogon $true; Add-ADGroupMember -Identity $vdiSecGroup -Members $_.alias}
    Import-CSV $csvFile | ForEach {Get-ADUser -Server "$domainDC" -Identity $_.alias -Properties * | select SamAccountName, Office, Description, PasswordExpired, MemberOf}
}
#End Script