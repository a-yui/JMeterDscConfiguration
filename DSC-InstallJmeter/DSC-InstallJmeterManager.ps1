#
# DSC-InstallJmeterManager.ps1
# 
Configuration InstallJmeterManager
{
    param (
      $vmssName,
      $resourceGroupName,
      $jmeterPath,
      $jmxPath,
      $DownloadPath = "$env:SystemDrive\dsctemp"
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -Module xSystemSecurity -Name xIEEsc

    Node localhost
    {
        xRemoteFile DownloadJRE
        {
            Uri = "http://javadl.oracle.com/webapps/download/AutoDL?BundleId=81821"
            DestinationPath = "$DownloadPath\JreInstall81821.exe"
        }

        xRemoteFile DownloadJMeter
        {
            Uri = $jmeterPath
            DestinationPath = "$DownloadPath\jmeter.zip"
        }

        xRemoteFile DownloadJMeterAgentSyncShell
        {
            Uri = "https://yuashivmtemp.blob.core.windows.net/dsc/Register-JmeterAgentIPAddress.ps1"
            DestinationPath = "$DownloadPath\JmeterAgentSyncShell.ps1"
        }

        xRemoteFile DownloadJmx
        {
            Uri = $jmxPath
            DestinationPath = "$DownloadPath\JmeterSettings.jmx"
        }

        Package Installer
        {
            # ProductIdは空白
            Ensure = 'Present'
            Name = "Java 7 Update 45 (64-bit)"
            Path = "$DownloadPath\JreInstall81821.exe"
            Arguments = "/s STATIC=1 WEB_JAVA=0 SPONSORS=0 INSTALLDIR=$env:SystemDrive\java\jre"
            ProductId = ''
            DependsOn = "[xRemoteFile]DownloadJRE"
        }

        Environment JavaPathEnvironment
        {
            Ensure = "Present"
            Name = "Path"
            Path = $true 
            Value = "$env:SystemDrive\java\jre\bin"
        }

        Archive ExtractJMeter {
            Ensure = "Present"
            Path = "$DownloadPath\jmeter.zip"
            Destination = "$env:SystemDrive"
            DependsOn = "[xRemoteFile]DownloadJMeter"
        }

        Script ModifyHeapSize{
            SetScript = 
            { 
                # JMeter.batのヒープサイズ書き換え
                $jmeterbatpath = "$env:SystemDrive\apache-jmeter-3.1\bin\jmeter.bat"
                $memory = Get-WmiObject -Class Win32_PhysicalMemory | %{ $_.Capacity} | Measure-Object -Sum | %{($_.sum /1024/1024)}
                $heap = [int]($memory * 0.8).ToString()

                $heapValue = "set HEAP=-Xms" + $heap + "m -Xmx" + $heap + "m"
                # Out-Fileでasciiに変換
                $file_contents = $(Get-Content $jmeterbatpath) -replace "set HEAP=-Xms512m -Xmx512m", $heapValue | Out-File -Encoding ascii $jmeterbatpath
            }
            TestScript = {
              $false
            }
            GetScript = {
              # Do Nothing
            }
            DependsOn = "[Archive]ExtractJMeter"
        }

        Script ModifyJMeterProperties{
            SetScript = 
            {
                $jmeterpropertiepath = "$env:SystemDrive\apache-jmeter-3.1\bin\jmeter.properties"

                $clientrmi = "client.rmi.localport=30000"
                $(Get-Content $jmeterpropertiepath) -replace "#client.rmi.localport=0", $clientrmi | Out-File -Encoding ascii $jmeterpropertiepath
            }
            TestScript = {
              $false
            }
            GetScript = {
              # Do Nothing
            }
            DependsOn = "[Script]ModifyHeapSize"
        }

        Script CreateJmeterShortcut{
            SetScript = 
            { 
                # ショートカットを作る
                $WsShell = New-Object -ComObject WScript.Shell
                $Shortcut = $WsShell.CreateShortcut("C:\Users\Public\Desktop\JMeter.lnk")
                $Shortcut.TargetPath = "$env:SystemDrive\apache-jmeter-3.1\bin\jmeter.bat"
                $Shortcut.Arguments = " -t $using:DownloadPath\JmeterSettings.jmx"
                $Shortcut.IconLocation = "$env:SystemDrive\apache-jmeter-3.1\bin\jmeter.bat"
                $Shortcut.Save()
            }
            TestScript = {
              $false
            }
            GetScript = {
              # Do Nothing
            }
            DependsOn = "[Script]ModifyHeapSize"
        }

        Script CreateJmeterAgentSyncShellShortcut{
            SetScript = 
            { 
                # ショートカットを作る
                # TargetPathに空白があるとエラーになる
                $WsShell = New-Object -ComObject WScript.Shell
                $Shortcut = $WsShell.CreateShortcut("C:\Users\Public\Desktop\JMeterAgentSyncShell.lnk")
                $Shortcut.TargetPath = "powershell"
                $Shortcut.Arguments = " -ExecutionPolicy RemoteSigned -File $using:DownloadPath\JmeterAgentSyncShell.ps1 -resourceGroupName $using:resourceGroupName -vmssName $using:vmssName"
                $Shortcut.IconLocation = "powershell.exe"
                $Shortcut.Save()
            }
            TestScript = {
              $false
            }
            GetScript = {
              # Do Nothing
            }
            DependsOn = "[xRemoteFile]DownloadJMeterAgentSyncShell"
        }

        xFirewall JMeterManagerFirewallRule
        { 
            Name                  = "JMeterManagerFirewallRule" 
            DisplayName           = "Firewall Rule for JMeterManager" 
            DisplayGroup          = "JMeter Firewall Rule Group" 
            Ensure                = "Present" 
            Access                = "Allow" 
            State                 = "Enabled" 
            Profile               = ("Domain", "Private", "Public") 
            Direction             = "InBound" 
            LocalPort             = ("30000")          
            Protocol              = "TCP" 
            Description           = "Firewall Rule for JMeterManager"   
        }

        xIEEsc DisableIEEscAdmin
        {
            IsEnabled = $False
            UserRole  = "Administrators"
        }
        xIEEsc EnableIEEscUser
        {
            IsEnabled = $False
            UserRole  = "Users"
        }

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }
    }
}