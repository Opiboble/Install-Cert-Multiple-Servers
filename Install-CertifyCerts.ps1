#Inbound Paramater
param($result)

#INI FIle location
$INIFile = "C:\Data\Certify\Certify-Cert-Install-Setting.ini"

#Load functions needed

#Creates Secure Credentials for Storing
Function Get-Credentials {
    Param (
	[String]$AuthUser = $env:USERNAME,
    [string]$PathToCred = "c:\data\scripts"
    )
    $Key = [byte]20,35,18,74,72,75,85,50,71,44,0,21,98,73,98,28

	#Check if folder exists/build folder
	Folder-checkandcreate -path $PathToCred

    #Build the path to the credential file
    $CredFile = $AuthUser.Replace("\","~")
    $File = $PathToCred + "\Credentials-$CredFile.crd"
    #And find out if it's there, if not create it
    If (-not (Test-Path $File))
    {	(Get-Credential $AuthUser).Password | ConvertFrom-SecureString -Key $Key | Set-Content $File
    }

    #Load the credential file
    $Password = Get-Content $File | ConvertTo-SecureString -Key $Key
    $AuthUser = (Split-Path $File -Leaf).Substring(12).Replace("~","\")
    $AuthUser = $AuthUser.Substring(0,$AuthUser.Length - 4)
    $Credential = New-Object System.Management.Automation.PsCredential($AuthUser,$Password)
    Return $Credential
}

#Check/build needed input path

Function Folder-checkandcreate {
	Param (
	[String]$Path = "c:\data"
	)

		If(!(test-path $path))
		{
			New-Item -ItemType Directory -Force -Path $path
		}
}

Get-Content "$INIFile" | foreach-object -begin {$Settings=@{}} -process { $k = [regex]::split($_,'=='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $Settings.Add($k[0], $k[1]) } }

## Variables from INI file
#Servers
$CertifyServer = $Settings.Get_Item("CertifyServer")
$ExchangeServer = $Settings.Get_Item("ExchangeServer")

#Account
$Account = $Settings.Get_Item("Account")

#Cert Thumb
$Thumb = $result.ManagedItem.CertificateThumbprintHash

#Credentials
$Cred = Get-Credentials -AuthUser $Account

#Save location & filename
$SavePath = "\\$Certify\c$\data\scripts"
$FullPath = "$SavePath\$Thumb.pfx"

#PFX Password
$rawpfxpswd = "ThisIsATest1234"
$pfxpswd = ConvertTo-SecureString -String "$rawpfxpswd" -Force -AsPlainText


#Create sessions needed

$SessionCertify = New-PSSession -ComputerName $Certify -Credential $Cred
$SessionExchange = New-PSSession -ComputerName $Exchange -Credential $Cred

#Pull cert from Certify Server and saved to \\$Certify\c$\data\$Thumb.pfx
Invoke-Command $SessionCertify -ScriptBlock {Get-ChildItem -Path cert:\localMachine\my\$using:Thumb | Export-PfxCertificate -FilePath $using:FullPath -Password $using:pfxpswd}


#Import to Exchange Server
Invoke-Command $SessionExchange -ScriptBlock {Get-ChildItem -Path $using:FullPath | Import-PfxCertificate -CertStoreLocation Cert:\LocalMachine\My -Exportable -Password $using:pfxpswd }

#Apply Cert to Exchange 2013+ Services
Invoke-Command $SessionExchange -ScriptBlock {Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn}
Invoke-Command $SessionExchange -ScriptBlock {Enable-ExchangeCertificate -Thumbprint $using:Thumb -Services POP,IMAP,SMTP,IIS}


#Notes
# key on exchange = 7D27C05C26629947362C5BD809C45E12548A4966
# key on wrkbnch = EED0ED6FFB213418F06EBAE4012AD09BE6598E10
# Old commands used
#Invoke-Command $s -ScriptBlock {$mypwd = ConvertTo-SecureString -String "1234" -Force -AsPlainText}
#Invoke-Command $s -ScriptBlock {certutil -p password -exportPFX My 7D27C05C26629947362C5BD809C45E12548A4966 c:\data\cert.pfx}
