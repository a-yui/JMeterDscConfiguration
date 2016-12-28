Configuration JavaInstall {
    param
    (
        [string]
        $BundleId = "81821", #7u45
        #$BundleId = "211999",
        [string]
        $LocalPath = "$env:SystemDrive\Windows\DtlDownloads\JRE7"
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    xRemoteFile Downloader
    {
        Uri = "http://javadl.oracle.com/webapps/download/AutoDL?BundleId=$BundleId"
        DestinationPath = "$LocalPath\JreInstall$BundleId.exe"
    }

    Package Installer
    {
        Ensure = 'Present'
        Name = "Java 7 Update 45 (64-bit)"
        Path = "$LocalPath\JreInstall$BundleId.exe"
        Arguments = "/s STATIC=1 WEB_JAVA=0 SPONSORS=0"
        ProductId = ''
        DependsOn = "[xRemoteFile]Downloader"
    }
    #Package Installer
    #{
    #    Ensure = 'Present'
    #    Name = 'Java 8 Update 101 (64-bit)'
    #    Path = "$LocalPath\JreInstall$BundleId.exe"
    #    Arguments = "/s REBOOT=0 SPONSORS=0 REMOVEOUTOFDATEJRES=1 INSTALL_SILENT=1 AUTO_UPDATE=0 EULA=0 /l*v `"$LocalPath\JreInstall$BundleId.log`""
    #    ProductId = '26A24AE4-039D-4CA4-87B4-2F64180101F0'
    #    DependsOn = "[xRemoteFile]Downloader"
    #}
}

Enable-PSRemoting -Force
Set-Item wsman:\localhost\Client\TrustedHosts -Value * -Force
Set-ExecutionPolicy Unrestricted 
Get-ChildItem “C:\Program Files\WindowsPowerShell\Modules\” –recurse | Unblock-File

$workingdir = 'C:\JAVAINSTALL\MOF'

# Create MOFJavaInstall -OutputPath $workingdir# Apply MOFStart-DscConfiguration -ComputerName 'localhost' -wait -force -verbose -path $workingdir

#http://stackoverflow.com/questions/31562451/installing-jre-using-powershell-dsc-hangs
#https://powershell.org/forums/topic/issue-installing-java-32-bit-using-package-resource/#post-39206

#JRE Install Option
#https://www.java.com/ja/download/help/silent_install.xml

get-wmiobject Win32_Product | Format-Table IdentifyingNumber, Name, LocalPackage
