#
# DSC-InstallJmeterAgent.ps1
# 
Configuration InstallJmeterAgent
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName xNetworking

    Node localhost
    {
        param
        (
            [string]
            $BundleId = "81821",
            [string]
            $DownloadPath = "$env:SystemDrive\dsctemp",
            [string]
            $JmeterPath = "http://ftp.kddilabs.jp/infosystems/apache/jmeter/binaries/apache-jmeter-3.1.zip"
        )
        
        xRemoteFile DownloadJRE
        {
            Uri = "http://javadl.oracle.com/webapps/download/AutoDL?BundleId=$BundleId"
            DestinationPath = "$DownloadPath\JreInstall$BundleId.exe"
        }

        Package Installer
        {
            # ProductIdは空白
            Ensure = 'Present'
            Name = "Java 7 Update 45 (64-bit)"
            Path = "$DownloadPath\JreInstall$BundleId.exe"
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

        xRemoteFile DownloadJMeter
        {
            Uri = $JmeterPath
            DestinationPath = "$DownloadPath\jmeter.zip"
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
                $serverrmi = "server.rmi.localport=4000"
                $file_contents = $(Get-Content $jmeterpropertiepath) -replace "#client.rmi.localport=0", $clientrmi
                $($file_contents) -replace "#server.rmi.localport=4000", $serverrmi | Out-File -Encoding ascii $jmeterpropertiepath
            }
            TestScript = {
              $false
            }
            GetScript = {
              # Do Nothing
            }
            DependsOn = "[Script]ModifyHeapSize"
        }

        Script CreateScheduleTask{
            SetScript = 
            { 
                #タスクスケジューラー登録
                $action = New-ScheduledTaskAction -Execute "$env:SystemDrive\apache-jmeter-3.1\bin\jmeter-server.bat"
                $trigger = New-ScheduledTaskTrigger -AtStartup
                Register-ScheduledTask -TaskPath \ -TaskName JMeterAgent -Action $action -Trigger $trigger -User "NT AUTHORITY\SYSTEM"
                Start-ScheduledTask -TaskName JMeterAgent
            }
            TestScript = {
              $false
            }
            GetScript = {
              # Do Nothing
            }
            DependsOn = "[Script]ModifyJMeterProperties"
        }

        xFirewall JMeterAgentFirewallRule
        { 
            Name                  = "JMeterAgentFirewallRule" 
            DisplayName           = "Firewall Rule for JMeterAgent" 
            DisplayGroup          = "JMeter Firewall Rule Group" 
            Ensure                = "Present" 
            Access                = "Allow" 
            State                 = "Enabled" 
            Profile               = ("Domain", "Private", "Public") 
            Direction             = "InBound" 
            LocalPort             = ("1099", "4000")          
            Protocol              = "TCP" 
            Description           = "Firewall Rule for JMeterAgent"   
        }

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }
    }
}