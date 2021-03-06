########################################
# Simple NSX environment standup script.
# Nick Bradford
# Nbradford@vmware.com
# 3TA elements courtesy of Anthony Burke : aburke@vmware.com

##########################################################################
# To use - edit and update variables with correct values.
# Sanity checking is done, but be sure you use correct values for your
# environment.
#
# The script performs four functions:
#
#  1 - To deploy NSX Manager/Controllers and configure infrastructure.
#       - Run NsxBuildFromScratch.ps1 -deploy3ta:$false
#  2 - To deploy the standard 3 tier app to an existing NSX deployment.
#       - Run NsxBuildFromScratch.ps1 -buildnsx:$false
#  3 - To deploy the whole shebang
#       - Run NsxBuildFromScratch.ps1
#  4 - To nuke everything deployed from #3.
#       - Run NsxBuildFromScratch.ps1 -nukeit:$true
#
# Note: If you are using NSX 6.2.3 or above, you will need to configure
# the license key in the below variable section.
#

<#
Copyright © 2017 VMware, Inc. All Rights Reserved.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License version 2, as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTIBILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License version 2 for more details.

You should have received a copy of the General Public License version 2 along with this program.
If not, see https://www.gnu.org/licenses/gpl-2.0.html.

The full text of the General Public License 2.0 is provided in the COPYING file.
Some files may be comprised of various open source software components, each of which
has its own license that is located in the source code of the respective component."
#>

#Requires -version 3.0
#Requires -modules PowerNSX, VMware.VimAutomation.Core

param (
    [switch]$buildnsx=$false,
    [switch]$deploy3ta=$false,
    [switch]$nukeit=$false
)

#vApp (3-Tier App)
# NB: No spaces allowed (hyphens OK)
$vAppName = "Books"

##########################################################################
# NSX Infrastructure Configuration.  Adjust to suit environment.
#

# NSX Manager Details
#
$NsxManagerOVF = "C:\Temp\VMware-NSX-Manager-6.2.6-4977495.ova"

# NSX License key is MANDATORY for 6.2.3 and above deployments.
$NsxLicenseKey = ""
$NsxManagerName = "nsx-m-01a"
$NsxManagerPassword = "VMware1!"
$NsxManagerIpAddress = "192.168.100.201"
$ControllerPoolStartIp = "192.168.100.202"
$ControllerPoolEndIp = "192.168.100.204"
$ControllerPassword = "VMware1!VMware1!"
$SegmentPoolStart = "5000"
$SegmentPoolEnd = "5999"
$TransportZoneName = "TransportZone1"

# vSphere Details
$vCenterServer = "vc-01a.corp.local"
$vCenterUserName = "administrator@vsphere.local"
$vCenterPassword = "VMware1!"
$MgmtClusterName = "Mgmt01"
$ManagementDatastoreName = "MgmtData"
$MgmtVdsName = "DSwitch"
$ComputeClusterName = "Mgmt01"
$ComputeVdsName = "DSwitch"
$EdgeClusterName = $MgmtClusterName
$EdgeDatastoreName = $ManagementDatastoreName
$ComputeDatastoreName = "MgmtData"

# Network Details
$ManagementNetworkPortGroupName = "Internal"
$ManagementNetworkSubnetMask = "255.255.255.0"
$ManagementNetworkSubnetPrefixLength = "24"
$ManagementNetworkGateway = "192.168.100.1"

$VxlanMtuSize = 1600

$MgmtVdsVxlanNetworkSubnetMask = "255.255.255.0"
$MgmtVdsVxlanNetworkSubnetPrefixLength = "24"
$MgmtVdsVxlanNetworkGateway = "172.16.110.1"
$MgmtVdsVxlanNetworkVlanId = "0"
$MgmtVdsVxlanVlanID = "0"
$MgmtVdsHostVtepCount = 1
$MgmtVdsVtepPoolStartIp = "172.16.110.201"
$MgmtVdsVtepPoolEndIp = "172.16.110.204"

$ComputeVdsVxlanNetworkSubnetMask = "255.255.255.0"
$ComputeVdsVxlanNetworkSubnetPrefixLength = "24"
$ComputeVdsVxlanNetworkGateway = "172.16.111.1"
$ComputeVdsVxlanNetworkVlanId = "0"
$ComputeVdsVxlanVlanID = "0"
$ComputeVdsHostVtepCount = 1
$ComputeVdsVtepPoolStartIp = "172.16.111.201"
$ComputeVdsVtepPoolEndIp = "172.16.111.204"

# Miscellaneous
$SyslogServer = "192.168.100.254"
$SysLogPort = 514
$SysLogProtocol = "TCP"
$NtpServer = "192.168.100.10"
$DnsServer1 = "192.168.100.10"
$DnsServer2 = "192.168.100.10"
$DnsSuffix = "corp.local"

# Reduce NSX Manager Memory - in GB.  Comment variable out for default.
$NsxManagerMem = 12

##########################################################################
# Physical to Virtual Connectivity On-Ramp
#
$EdgeUplinkPrimaryAddress = "192.168.100.192"
$EdgeUplinkSecondaryAddress = "192.168.100.193"
$EdgeDefaultGW = "192.168.100.1"
$EdgeUplinkNetworkName = $ManagementNetworkPortGroupName
$AppliancePassword = "VMware1!VMware1!"
$3TiervAppLocation = "C:\Temp\3_Tier-App-v1.6.ova"
# Get v1.6 of the vApp from http://goo.gl/ujxYz1


##########################################################################
# Topology Details. No need to modify below here.
#

# Switch Names
$TransitLsName = "LS-Transit"
$WebLsName = "LS-Web"
$AppLsName = "LS-App"
$DbLsName = "LS-DB"
$MgmtLsName = "LS-Mgmt"
$EdgeName = "esg01"
$LdrName = "dlr01"

# Topology
$EdgeInternalPrimaryAddress = "172.16.1.1"
$EdgeInternalSecondaryAddress = "172.16.1.6"
$LdrUplinkPrimaryAddress = "172.16.1.2"
$LdrUplinkProtocolAddress = "172.16.1.3"
$LdrWebPrimaryAddress = "10.0.1.1"
$LdrAppPrimaryAddress = "10.0.2.1"
$LdrDbPrimaryAddress = "10.0.3.1"
$TransitOspfAreaId = "10"
$DefaultSubnetMask = "255.255.255.0"
$DefaultSubnetBits = "24"

#WebTier VMs
$Web01Name = "Web01"
$Web01Ip = "10.0.1.11"
$Web02Name = "Web02"
$Web02Ip = "10.0.1.12"

#AppTier VMs
$App01Name = "App01"
$App01Ip = "10.0.2.11"
$App02Name = "App02"
$App02Ip = "10.0.2.12"

#DB Tier VMs
$Db01Name = "DB01"
$Db01Ip = "10.0.3.11"

##LoadBalancer
$LbAlgo = "round-robin"
$WebpoolName = "WebPool1"
$ApppoolName = "AppPool1"
$WebVipName = "WebVIP"
$AppVipName = "AppVIP"
$WebAppProfileName = "WebAppProfile"
$AppAppProfileName = "AppAppProfile"
$VipProtocol = "http"
$HttpPort = "80"
$LBMonitorName = "default_http_monitor"

## Security Groups
$WebSgName = "$vAppName-SG-Web"
$WebSgDescription = "$vAppName Web Tier Security Group"
$AppSgName = "$vAppName-SG-App"
$AppSgDescription = "$vAppName App Tier Security Group"
$DbSgName = "$vAppName-SG-DB"
$DbSgDescription = "$vAppName DB Tier Security Group"
$vAppSgName = "$vAppName-SG-ALL"
$vAppSgDescription = "$vAppName ALL Security Group"

## Security Tags
$WebStName = "$vAppName-ST-Web"
$AppStName = "$vAppName-ST-App"
$DbStName = "$vAppName-ST-DB"

##IPset
$AppVIP_IpSet_Name = "$vAppName-IpSet-EdgeAppVIP"
$InternalESG_IpSet_Name = "$vAppName-IpSet-EdgeInsideVIP"

##DFW
$FirewallSectionName = $vAppName

###############################################
# Do Not modify below here.
###############################################

###############################################
###############################################
# Constants

$WaitStep = 30
$WaitTimeout = 600
$yesnochoices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$yesnochoices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$yesnochoices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

###############################################
# Filters

filter timestamp {"$(Get-Date -Format G): $_"}

###############################
# Validation
# Connect to vCenter
# Check for PG, DS, Cluster

#Get Connection required.
try {
    if ( -not $buildnsx ) {
        Write-Output "`nConnecting to NSX Manager $NsxManagerName ..." | timestamp
        Connect-NsxServer -server $NsxManagerIpAddress -Username 'admin' -password $NsxManagerPassword -VIUsername $vCenterUserName -VIPassword $vCenterPassword -ViWarningAction Ignore -DebugLogging | out-null
    }
    else {
        Write-Output "Connecting to vCenter $vCenterServer ..." | timestamp
        if ( -not $DefaultViConnection.IsConnected ) {
            connect-ViServer -Server $vCenterServer -User $vCenterUserName -Password $vCenterPassword -WarningAction Ignore | out-null
        }
    }
}
catch {
    Throw "Connection failed. Check connection details and try again.  $_"
}

#Check that the vCenter env looks correct for deployment.
try {
    $MgmtCluster = Get-Cluster $MgmtClusterName -errorAction Stop
    $ComputeCluster = Get-Cluster $ComputeClusterName -errorAction Stop
    $EdgeCluster = get-cluster $EdgeClusterName -errorAction Stop
    $EdgeDatastore = get-datastore $EdgeDatastoreName -errorAction Stop
    $MgmtDatastore = Get-Datastore $ManagementDatastoreName -errorAction Stop
    $ManagementPortGroup = Get-VdPortGroup $ManagementNetworkPortGroupName -errorAction Stop
    $MgmtVds = Get-VdSwitch $MgmtVdsName -errorAction Stop
    $CompVds = $ComputeCluster | get-vmhost | Get-VdSwitch $ComputeVdsName -errorAction Stop
    if ( -not $CompVds ) { throw "Compute cluster hosts are not configured with compute VDSwitch."}
    $ComputeDatastore = get-datastore $ComputeDatastoreName -errorAction Stop
    $EdgeUplinkNetwork = get-vdportgroup $EdgeUplinkNetworkName -errorAction Stop
}
catch {
    Throw "Failed validating vSphere Environment. $_"
}

If ( $deploy3ta ) {

    # Compute details - finds the host with the least used memory for deployment.
    $DeploymentVMHost = $Computecluster | Get-VMHost | Sort-Object MemoryUsageGB | Select-Object -first 1
    if ( -not ( Test-Connection $($DeploymentVMHost.name) -count 1 -ErrorAction Stop )) {
        throw "Unable to validate connection to target ESX host $($DeploymentVMHost.Name) used to deploy OVF."
    }

    Write-Output "Validating environment in preparation for $vAppName vApp deployment ..." | timestamp
    if ( -not ( test-path $3TiervAppLocation )) { throw "$3TiervAppLocation not found."}
}
if ( $deploy3ta -and ( -not $buildnsx)) {
    #If Deploying 3ta, check that things exist
    try {

        #Failed deployment stuff
        if ( Get-NsxLogicalSwitch $WebLsName ) {
            throw "Logical Switch already exists.  Please remove and try again."
        }
        if ( Get-NsxLogicalSwitch $AppLsName ) {
            throw "Logical Switch already exists.  Please remove and try again."
        }
        if ( Get-NsxLogicalSwitch $DbLsName ) {
            throw "Logical Switch already exists.  Please remove and try again."
        }
        if ( Get-NsxLogicalSwitch $TransitLsName ) {
            throw "Logical Switch already exists.  Please remove and try again."
        }
        if ( (get-nsxservice "$vAppName-tcp-80") -or (get-nsxservice "$vAppName-tcp-3306" ) ) {
            throw "Custom services already exist.  Please remove and try again."
        }
        if ( get-vapp $vAppName -ErrorAction SilentlyContinue ) {
            throw "vApp already exists.  Please remove and try again."
        }
        if ( get-nsxedge $EdgeName ) {
            throw "Edge already exists.  Please remove and try again."
        }
        if ( get-nsxlogicalrouter $LdrName ) {
            throw "Logical Router already exists.  Please remove and try again."
        }
        if ( get-nsxsecurityGroup $WebSgName ) {
            throw "Security Group exists.  Please remove and try again."
        }
        if ( get-nsxsecurityGroup $AppSgName ) {
            throw "Security Group exists.  Please remove and try again."
        }
        if ( get-nsxsecurityGroup $DbSgName ) {
            throw "Security Group exists.  Please remove and try again."
        }
        if ( get-nsxsecurityGroup $vAppSgName ) {
            throw "Security Group already exists.  Please remove and try again."
        }
        if ( get-nsxfirewallsection $FirewallSectionName ) {
            throw "Firewall Section already exists.  Please remove and try again."
        }
        if ( get-nsxsecuritytag $WebStName ) {
            throw "Security Tag already exists.  Please remove and try again."
        }
        if ( get-nsxsecuritytag $AppStName ) {
            throw "Security Tag already exists.  Please remove and try again."
        }
        if ( get-nsxsecuritytag $DbStName ) {
            throw "Security Tag already exists.  Please remove and try again."
        }
        if ( Get-nsxipset $AppVIP_IpSet_Name ) {
            throw "IPSet already exists.  Please remove and try again."
        }
        if ( Get-nsxipset $InternalESG_IpSet_Name ) {
            throw "IPSet already exists.  Please remove and try again."
        }

    }
    catch {
        Throw "Failed validating environment for 3ta deployment.  $_"
    }
}


#PowerCLI 6 is required due to OvfConfiguration commands.
[int]$PowerCliMajorVersion = (Get-PowerCliVersion).major
if ( -not ($PowerCliMajorVersion -ge 6 ) ) { throw "OVF deployment tools requires PowerCLI version 6 or above" }

if ( $buildnsx ) {
    #
    ###############################
    # Deploy NSX Manager appliance.

    Write-Output "Deploying NSX Manager ..." | timestamp
    try {
        New-NsxManager -NsxManagerOVF $NsxManagerOVF -Name $NsxManagerName -ClusterName $MgmtClusterName -ManagementPortGroupName $ManagementNetworkPortGroupName -DatastoreName $ManagementDatastoreName -CliPassword $NsxManagerPassword -CliEnablePassword $NsxManagerPassword -Hostname $NsxManagerName -IpAddress $NsxManagerIpAddress -Netmask $ManagementNetworkSubnetMask -Gateway $ManagementNetworkGateway -DnsServer $DnsServer1 -DnsDomain $DnsSuffix -NtpServer $NtpServer -EnableSsh -StartVM -Wait -FolderName vm -ManagerMemoryGB $NsxManagerMem | out-null

        Connect-NsxServer -server $NsxManagerIpAddress -Username 'admin' -password $NsxManagerPassword -DisableViAutoConnect -ViWarningAction Ignore | out-null

    }
    catch {

        Throw "An error occured during NSX Manager deployment.  $_"
    }
    Write-Output "Complete.`n" | timestamp



    ###############################
    # Configure NSX Manager appliance.

    try {
        Write-Output "Configuring NSX Manager ..." | timestamp

        Write-Output "  -> Performing NSX Manager syslog configuration" | timestamp
        Set-NsxManager -SyslogServer $SyslogServer -SyslogPort $SysLogPort -SyslogProtocol $SysLogProtocol | out-null

        Write-Output "  -> Performing NSX Manager SSO configuration" | timestamp
        Set-NsxManager -SsoServer $vCenterServer -SsoUserName $vCenterUserName -SsoPassword $vCenterPassword | out-null

        Write-Output "  -> Performing NSX Manager vCenter registration with account $vCenterUserName" | timestamp
        Set-NsxManager -vCenterServer $vCenterServer -vCenterUserName $vCenterUserName -vCenterPassword $vCenterPassword | out-null

        Write-Output "  -> Establishing full connection to NSX Manager and vCenter" | timestamp
        #Update the connection with VI connection details...
        Connect-NsxServer -server $NsxManagerIpAddress -Username 'admin' -password $NsxManagerPassword -VIUsername $vCenterUserName -VIPassword $vCenterPassword -ViWarningAction Ignore -DebugLogging | out-null
        Write-Output "`n"
    }
    catch {

        Throw "Exception occurred configuring NSX Manager.  $_"

    }

    Write-Output "Complete.`n" | timestamp

    ##############################
    # Install NSX License
    Write-Output "Installing NSX License ..." | timestamp

    if ( $DefaultNSXConnection.Version -gt 6.2.3) {
        try {
            $ServiceInstance = Get-View ServiceInstance
            $LicenseManager = Get-View $ServiceInstance.Content.licenseManager
            $LicenseAssignmentManager = Get-View $LicenseManager.licenseAssignmentManager
            $LicenseAssignmentManager.UpdateAssignedLicense("nsx-netsec",$NsxLicenseKey,$NULL)
        }
        catch {
            throw "Unable to configure NSX license.  Check the license is valid and try again."
        }
    }
    Write-Output "Complete.`n" | timestamp


    ###############################
    # Deploy NSX Controllers

    Write-Output "Deploying NSX Controllers ..." | timestamp

    try {

        Write-Output "  -> Creating IP Pool for Controller addressing" | timestamp

        $ControllerPool = New-NsxIpPool -Name "Controllers_Pool" -Gateway $ManagementNetworkGateway -SubnetPrefixLength $ManagementNetworkSubnetPrefixLength -DnsServer1 $DnsServer1 -DnsServer2 $DnsServer2 -DnsSuffix $DnsSuffix -StartAddress $ControllerPoolStartIp -EndAddress $ControllerPoolEndIp

        for ( $i=0; $i -le 2; $i++ ) {

            Write-Output "  -> Deploying NSX Controller $($i+1)" | timestamp
            try {

                $Controller = New-NsxController -ipPool $ControllerPool -Cluster $MgmtCluster -datastore $MgmtDatastore -PortGroup $ManagementPortGroup -password $ControllerPassword -confirm:$false -wait
            }
            catch {
                throw "Controller $($i+1) deployment failed. $_"
            }
            Write-Output "  -> Controller $($i+1) online." | timestamp
        }
    }
    catch {

        Throw  "Controller Cluster deployment failed. $_"
    }

    Write-Output "Complete.`n" | timestamp


    ##############################
    # Prep VDS

    Write-Output "Configuring VDS for use with NSX ..." | timestamp

    try {
        #This is assuming two or more NICs on the uplink PG on this VDS.  No LAG required, and results in load balance accross multiple uplink NICs
        New-NsxVdsContext -VirtualDistributedSwitch $MgmtVds -Teaming "LOADBALANCE_SRCID" -Mtu $VxlanMtuSize | out-null
        New-NsxVdsContext -VirtualDistributedSwitch $CompVds -Teaming "LOADBALANCE_SRCID" -Mtu $VxlanMtuSize | out-null

    }
    catch {
        Throw  "VDS configuration failed. $_"

    }

    Write-Output "Complete.`n" | timestamp

    ##############################
    # Prep Clusters

    Write-Output "Preparing clusters for NSX ..." | timestamp


    try {

        Write-Output "  -> Creating IP Pools for VTEP addressing" | timestamp

        $MgmtVtepPool = New-NsxIpPool -Name "Edge_VTEP" -Gateway $MgmtVdsVxlanNetworkGateway -SubnetPrefixLength $MgmtVdsVxlanNetworkSubnetPrefixLength -DnsServer1 $DnsServer1 -DnsServer2 $DnsServer2 -DnsSuffix $DnsSuffix -StartAddress $MgmtVdsVtepPoolStartIp -EndAddress $MgmtVdsVtepPoolEndIp

        $Compute01VtepPool = New-NsxIpPool -Name "Compute_VTEP" -Gateway $ComputeVdsVxlanNetworkGateway -SubnetPrefixLength $ComputeVdsVxlanNetworkSubnetPrefixLength -DnsServer1 $DnsServer1 -DnsServer2 $DnsServer2 -DnsSuffix $DnsSuffix -StartAddress $ComputeVdsVtepPoolStartIp -EndAddress $ComputeVdsVtepPoolEndIp

        Write-Output "  -> Preparing cluster $MgmtClusterName and configuring VXLAN" | timestamp
        Get-Cluster $MgmtCluster | New-NsxClusterVxlanConfig -VirtualDistributedSwitch $MgmtVds -Vlan $MgmtVdsVxlanVlanID -VtepCount $MgmtVdsHostVtepCount -ipPool $MgmtVtepPool| out-null

        Write-Output "  -> Preparing cluster $ComputeClusterName and configuring VXLAN" | timestamp
        Get-Cluster $ComputeCluster | New-NsxClusterVxlanConfig -VirtualDistributedSwitch $CompVds -Vlan $ComputeVdsVxlanVlanID -VtepCount $ComputeVdsHostVtepCount -ipPool $Compute01VtepPool | out-null


    }
    catch {
        Throw  "Failed preparing clusters for NSX.  $_"

    }
    Write-Output "Complete`n" | timestamp


    ##############################
    # Configure Segment Pool

    Write-Output "Configuring Segment ID pool ..." | timestamp

    try {

            Write-Output "  -> Creating Segment ID pool" | timestamp
            New-NsxSegmentIdRange -Name "SegmentIDPool" -Begin $SegmentPoolStart -end $SegmentPoolEnd | out-null
    }
    catch {
        Throw  "Segment ID pool creation failed. $_"
    }

    Write-Output "Complete.`n" | timestamp

    ##############################
    # Create Transport Zone

    Write-Output "Configuring Transport Zone ..." | timestamp

    try {

        Write-Output "  -> Creating Transport Zone $TransportZoneName" | timestamp
        #Configure TZ and add clusters.
        New-NsxTransportZone -Name $TransportZoneName -Cluster $MgmtCluster, $ComputeCluster -ControlPlaneMode "UNICAST_MODE" | out-null

    }
    catch {
        Throw  "Transport Zone configuration failed. $_"

    }

    Write-Output "`nNSX infrastructure configuration complete.`n" | timestamp
}

if ( $deploy3ta ) {

    ######################################
    ######################################
    ## Topology Deployment

    Write-Output "Beginning deployment of $vAppName vApp ...`n" | timestamp


    ######################################
    #Logical Switches

    Write-Output "Creating NSX Logical Switches ..." | timestamp

    ## Creates four logical switches
    Write-Output "  -> Creating $TransitLsName" | timestamp
    $TransitLs = Get-NsxTransportZone | New-NsxLogicalSwitch $TransitLsName
    Write-Output "  -> Creating $WebLsName" | timestamp
    $WebLs = Get-NsxTransportZone | New-NsxLogicalSwitch $WebLsName
    Write-Output "  -> Creating $AppLsName" | timestamp
    $AppLs = Get-NsxTransportZone | New-NsxLogicalSwitch $AppLsName
    Write-Output "  -> Creating $DbLsName" | timestamp
    $DbLs = Get-NsxTransportZone | New-NsxLogicalSwitch $DbLsName
    Write-Output "  -> Creating $MgmtLsName" | timestamp
    $MgmtLs = Get-NsxTransportZone | New-NsxLogicalSwitch $MgmtLsName
    Write-Output "`n"


    ######################################
    # DLR

    # DLR Appliance has the uplink router interface created first.
    Write-Output "Deploying NSX Distributed Logical Router ($LdrName) ..." | timestamp
    $LdrvNic0 = New-NsxLogicalRouterInterfaceSpec -type Uplink -Name $TransitLsName -ConnectedTo $TransitLs -PrimaryAddress $LdrUplinkPrimaryAddress -SubnetPrefixLength $DefaultSubnetBits

    # The DLR is created with the first vnic defined, and the datastore and cluster on which the Control VM will be deployed.
    $Ldr = New-NsxLogicalRouter -name $LdrName -ManagementPortGroup $MgmtLs -interface $LdrvNic0 -cluster $EdgeCluster -datastore $EdgeDataStore

    ## Adding DLR interfaces after the DLR has been deployed. This can be done any time if new interfaces are required.
    Write-Output "  -> $LdrName`: Adding Web LIF" | timestamp
    $Ldr | New-NsxLogicalRouterInterface -Type Internal -name $WebLsName  -ConnectedTo $WebLs -PrimaryAddress $LdrWebPrimaryAddress -SubnetPrefixLength $DefaultSubnetBits | out-null
    Write-Output "  -> $LdrName`: Adding App LIF" | timestamp
    $Ldr | New-NsxLogicalRouterInterface -Type Internal -name $AppLsName  -ConnectedTo $AppLs -PrimaryAddress $LdrAppPrimaryAddress -SubnetPrefixLength $DefaultSubnetBits | out-null
    Write-Output "  -> $LdrName`: Adding DB LIF" | timestamp
    $Ldr | New-NsxLogicalRouterInterface -Type Internal -name $DbLsName  -ConnectedTo $DbLs -PrimaryAddress $LdrDbPrimaryAddress -SubnetPrefixLength $DefaultSubnetBits | out-null

    ## DLR Routing - default route from DLR with a next-hop of the Edge.
    Write-Output "  -> $LdrName`: Setting default route next-hop to $EdgeInternalPrimaryAddress" | timestamp

    ##The first line pulls the uplink name coz we cant assume we know the index ID
    $LdrTransitInt = get-nsxlogicalrouter | get-nsxlogicalrouterinterface | Where-Object { $_.name -eq $TransitLsName}
    Get-NsxLogicalRouter $LdrName | Get-NsxLogicalRouterRouting | Set-NsxLogicalRouterRouting -DefaultGatewayVnic $LdrTransitInt.index -DefaultGatewayAddress $EdgeInternalPrimaryAddress -confirm:$false | out-null
    Write-Output "`n"


    ######################################
    # EDGE

    ## Defining the uplink and internal interfaces to be used when deploying the edge. Note there are two IP addresses on these interfaces. $EdgeInternalSecondaryAddress and $EdgeUplinkSecondaryAddress are the VIPs
    $edgevnic0 = New-NsxEdgeinterfacespec -index 0 -Name "Uplink" -type Uplink -ConnectedTo $EdgeUplinkNetwork -PrimaryAddress $EdgeUplinkPrimaryAddress -SecondaryAddress $EdgeUplinkSecondaryAddress -SubnetPrefixLength $DefaultSubnetBits
    $edgevnic1 = New-NsxEdgeinterfacespec -index 1 -Name $TransitLsName -type Internal -ConnectedTo $TransitLs -PrimaryAddress $EdgeInternalPrimaryAddress -SubnetPrefixLength $DefaultSubnetBits -SecondaryAddress $EdgeInternalSecondaryAddress

    ## Deploy appliance with the defined uplinks
    Write-Output "Deploying NSX Edge Services Gateway ($EdgeName) ..." | timestamp
    $Edge1 = New-NsxEdge -name $EdgeName -cluster $EdgeCluster -datastore $EdgeDataStore -Interface $edgevnic0, $edgevnic1 -Password $AppliancePassword -FwDefaultPolicyAllow

    ##Configure Edge DGW
    Get-NSXEdge $EdgeName | Get-NsxEdgeRouting | Set-NsxEdgeRouting -DefaultGatewayAddress $EdgeDefaultGW -confirm:$false | out-null

    #####################################
    # Load LoadBalancer

    # Enanble Loadbalancing on $edgeName
    Write-Output "  -> $EdgeName`: Enabling load balancer" | timestamp
    Get-NsxEdge $EdgeName | Get-NsxLoadBalancer | Set-NsxLoadBalancer -Enabled | out-null

    #Get default monitor.
    $monitor =  get-nsxedge $EdgeName | Get-NsxLoadBalancer | Get-NsxLoadBalancerMonitor -Name $LBMonitorName

    # Define pool members.  By way of example we will use two different methods for defining pool membership.  Webpool via predefine memberspec first...
    Write-Output "  -> $EdgeName`: Creating server pool for Web tier" | timestamp
    $webpoolmember1 = New-NsxLoadBalancerMemberSpec -name $Web01Name -IpAddress $Web01Ip -Port $HttpPort
    $webpoolmember2 = New-NsxLoadBalancerMemberSpec -name $Web02Name -IpAddress $Web02Ip -Port $HttpPort

    # ... And create the web pool
    $WebPool =  Get-NsxEdge $EdgeName | Get-NsxLoadBalancer | New-NsxLoadBalancerPool -name $WebPoolName -Description "Web Tier Pool" -Transparent:$false -Algorithm $LbAlgo -Memberspec $webpoolmember1, $webpoolmember2 -Monitor $Monitor

    # Now method two for the App Pool  Create the pool with empty membership.
    Write-Output "  -> $EdgeName`: Creating server pool for App tier" | timestamp
    $AppPool = Get-NsxEdge $EdgeName | Get-NsxLoadBalancer | New-NsxLoadBalancerPool -name $AppPoolName -Description "App Tier Pool" -Transparent:$false -Algorithm $LbAlgo -Monitor $Monitor

    # ... And now add the pool members
    $AppPool = $AppPool | Add-NsxLoadBalancerPoolMember -name $App01Name -IpAddress $App01Ip -Port $HttpPort
    $AppPool = $AppPool | Add-NsxLoadBalancerPoolMember -name $App02Name -IpAddress $App02Ip -Port $HttpPort

    # Create App Profiles. It is possible to use the same but for ease of operations this will be two here.
    Write-Output "  -> $EdgeName`: Creating application profiles for Web and App tiers" | timestamp
    $WebAppProfile = Get-NsxEdge $EdgeName | Get-NsxLoadBalancer | New-NsxLoadBalancerApplicationProfile -Name $WebAppProfileName  -Type $VipProtocol
    $AppAppProfile = Get-NsxEdge $EdgeName | Get-NsxLoadBalancer | New-NsxLoadBalancerApplicationProfile -Name $AppAppProfileName  -Type $VipProtocol

    # Create VIPs for the relevant Web Pools using the edge's secondary IP addresses.
    Write-Output "  -> $EdgeName`: Creating virtual servers (VIPs)" | timestamp
    Get-NsxEdge $EdgeName | Get-NsxLoadBalancer | Add-NsxLoadBalancerVip -name $WebVipName -Description $WebVipName -ipaddress $EdgeUplinkSecondaryAddress -Protocol $VipProtocol -Port $HttpPort -ApplicationProfile $WebAppProfile -DefaultPool $WebPool -AccelerationEnabled | out-null
    Get-NsxEdge $EdgeName | Get-NsxLoadBalancer | Add-NsxLoadBalancerVip -name $AppVipName -Description $AppVipName -ipaddress $EdgeInternalSecondaryAddress -Protocol $VipProtocol -Port $HttpPort -ApplicationProfile $AppAppProfile -DefaultPool $AppPool -AccelerationEnabled | out-null
    Write-Output "`n"


    ####################################
    # Dynamic routing

    Write-Output "Configuring dynamic routing ..." | timestamp
    Write-Output "  -> Configuring OSPF on $EdgeName" | timestamp
    Get-NsxEdge $EdgeName | Get-NsxEdgerouting | set-NsxEdgeRouting -EnableOspf -RouterId $EdgeUplinkPrimaryAddress -confirm:$false | out-null

    #Remove the dopey area 51 NSSA - just to show example of complete OSPF configuration including area creation.
    Get-NsxEdge $EdgeName | Get-NsxEdgerouting | Get-NsxEdgeOspfArea -AreaId 51 | Remove-NsxEdgeOspfArea -confirm:$false

    #Create new Area 0 for OSPF
    Get-NsxEdge $EdgeName | Get-NsxEdgerouting | New-NsxEdgeOspfArea -AreaId $TransitOspfAreaId -Type normal -confirm:$false | out-null

    #Area to interface mapping
    Get-NsxEdge $EdgeName | Get-NsxEdgerouting | New-NsxEdgeOspfInterface -AreaId $TransitOspfAreaId -vNic 1 -confirm:$false | out-null

    Write-Output "  -> Configuring OSPF on $LdrName" | timestamp
    Get-NsxLogicalRouter $LdrName | Get-NsxLogicalRouterRouting | set-NsxLogicalRouterRouting -EnableOspf -EnableOspfRouteRedistribution -RouterId $LdrUplinkPrimaryAddress -ProtocolAddress $LdrUplinkProtocolAddress -ForwardingAddress $LdrUplinkPrimaryAddress  -confirm:$false | out-null

    #Remove the dopey area 51 NSSA - just to show example of complete OSPF configuration including area creation.
    Get-NsxLogicalRouter $LdrName | Get-NsxLogicalRouterRouting | Get-NsxLogicalRouterOspfArea -AreaId 51 | Remove-NsxLogicalRouterOspfArea -confirm:$false

    #Create new Area
    Get-NsxLogicalRouter $LdrName | Get-NsxLogicalRouterRouting | New-NsxLogicalRouterOspfArea -AreaId $TransitOspfAreaId -Type normal -confirm:$false | out-null

    #Area to interface mapping
    $LdrTransitInt = get-nsxlogicalrouter | get-nsxlogicalrouterinterface | Where-Object { $_.name -eq $TransitLsName}
    Get-NsxLogicalRouter $LdrName | Get-NsxLogicalRouterRouting | New-NsxLogicalRouterOspfInterface -AreaId $TransitOspfAreaId -vNic $LdrTransitInt.index -confirm:$false | out-null
    Write-Output "`n"


    ####################################
    # OVF Application

    Write-Output "Deploying VM images for $vAppName vApp ..." | timestamp

    # vCenter and the VDS have no understanding of a "Logical Switch". It only sees it as a VDS port group.
    # This step uses Get-NsxBackingPortGroup to determine the actual PG name that the VM attaches to.
    # Also - realise that a single LS could be (and is here) backed by multiple PortGroups, so we need to
    # get the PG in the right VDS (compute)
    # First work out the VDS used in the compute cluster (This assumes you only have a single VDS per cluster.
    # If that isn't the case, we need to get the VDS by name....:

    $WebNetwork = get-nsxtransportzone | get-nsxlogicalswitch $WebLsName | Get-NsxBackingPortGroup | Where-Object { $_.VDSwitch -eq $CompVds }
    $AppNetwork = get-nsxtransportzone | get-nsxlogicalswitch $AppLsName | Get-NsxBackingPortGroup | Where-Object { $_.VDSwitch -eq $CompVds }
    $DbNetwork = get-nsxtransportzone | get-nsxlogicalswitch $DbLsName | Get-NsxBackingPortGroup | Where-Object { $_.VDSwitch -eq $CompVds }

    # Get OVF configuration so we can modify it.
    $OvfConfiguration = Get-OvfConfiguration -Ovf $3TiervAppLocation

    # Network attachment.
    $OvfConfiguration.NetworkMapping.vxw_dvs_24_virtualwire_3_sid_10001_Web_LS_01.Value = $WebNetwork.name
    $OvfConfiguration.NetworkMapping.vxw_dvs_24_virtualwire_4_sid_10002_App_LS_01.Value = $AppNetwork.name
    $OvfConfiguration.NetworkMapping.vxw_dvs_24_virtualwire_5_sid_10003_DB_LS_01.Value = $DbNetwork.name

    # VM details.
    $OvfConfiguration.common.app_ip.Value = $EdgeInternalSecondaryAddress
    $OvfConfiguration.common.Web01_IP.Value = $Web01Ip
    $OvfConfiguration.common.Web02_IP.Value = $Web02Ip
    $OvfConfiguration.common.Web_Subnet.Value = $DefaultSubnetMask
    $OvfConfiguration.common.Web_Gateway.Value = $LdrWebPrimaryAddress
    $OvfConfiguration.common.App01_IP.Value = $App01Ip
    $OvfConfiguration.common.App02_IP.Value = $App02Ip
    $OvfConfiguration.common.App_Subnet.Value = $DefaultSubnetMask
    $OvfConfiguration.common.App_Gateway.Value = $LdrAppPrimaryAddress
    $OvfConfiguration.common.DB01_IP.Value = $DB01Ip
    $OvfConfiguration.common.DB_Subnet.Value = $DefaultSubnetMask
    $OvfConfiguration.common.DB_Gateway.Value = $LdrDbPrimaryAddress



    # Run the deployment.
    Import-vApp -Source $3TiervAppLocation -OvfConfiguration $OvfConfiguration -Name $vAppName -Location $ComputeCluster -VMHost $DeploymentVmhost -Datastore $ComputeDatastore | out-null
    Write-Output "Starting VMs for $vAppName vApp ..." | timestamp
    try {
        Start-vApp $vAppName | out-null
        }
    catch {
        Write-Warning "Something is wrong with the vApp. Check if it has finished deploying. Press a key to continue.";
        $Key = [console]::ReadKey($true)
    }
    Write-Output "`n"

    #####################################
    # Microseg config

    Write-Output "Configuring NSX Distributed Firewall ..." | timestamp

    # Assume these services exist which they do in a default NSX deployment.
    Write-Output "  -> Getting service definitions" | timestamp
    $httpservice = New-NsxService -name "$vAppName-tcp-80" -protocol tcp -port "80"
    $mysqlservice = New-NsxService -name "$vAppName-tcp-3306" -protocol tcp -port "3306"

    #Create Security Tags
    Write-Output "  -> Creating security tags" | timestamp
    $WebSt = New-NsxSecurityTag -name $WebStName
    $AppSt = New-NsxSecurityTag -name $AppStName
    $DbSt = New-NsxSecurityTag -name $DbStName


    # Create IP Sets
    Write-Output "  -> Creating IP sets" | timestamp
    $AppVIP_IpSet = New-NsxIPSet -Name $AppVIP_IpSet_Name -IPAddresses $EdgeInternalSecondaryAddress
    $InternalESG_IpSet = New-NsxIPSet -name $InternalESG_IpSet_Name -IPAddresses $EdgeInternalPrimaryAddress

    #Create SecurityGroups and with static includes
    Write-Output "  -> Creating security groups" | timestamp
    $WebSg = New-NsxSecurityGroup -name $WebSgName -description $WebSgDescription -includemember $WebSt
    $AppSg = New-NsxSecurityGroup -name $AppSgName -description $AppSgDescription -includemember $AppSt
    $DbSg = New-NsxSecurityGroup -name $DbSgName -description $DbSgDescription -includemember $DbSt
    $vAppSg = New-NsxSecurityGroup -name $vAppSgName -description $vAppSgName -includemember $WebSg, $AppSg, $DbSg

    # Apply Security Tag to VM's for Security Group membership
    $WebVMs = Get-Vm | Where-Object {$_.name -match ("web0")}
    $AppVMs = Get-Vm | Where-Object {$_.name -match ("app0")}
    $DbVMs = Get-Vm | Where-Object {$_.name -match ("db0")}

    $WebSt | New-NsxSecurityTagAssignment -ApplyToVm -VirtualMachine $WebVMs | Out-Null
    $AppSt | New-NsxSecurityTagAssignment -ApplyToVm -VirtualMachine $AppVMs | Out-Null
    $DbSt | New-NsxSecurityTagAssignment -ApplyToVm -VirtualMachine $DbVMs | Out-Null

    #Building firewall section with value defined in $FirewallSectionName
    Write-Output "  -> Creating rule section for $vAppName" | timestamp

    $FirewallSection = new-NsxFirewallSection $FirewallSectionName

    #Actions
    $AllowTraffic = "allow"
    $DenyTraffic = "deny"

    #Allows Web VIP to reach WebTier
    Write-Output "  -> Creating Web Tier rules" | timestamp
    $SourcesRule = get-nsxfirewallsection $FirewallSectionName | New-NSXFirewallRule -Name "VIP to Web" -Source $InternalESG_IpSet -Destination $WebSg -Service $HttpService -Action $AllowTraffic -AppliedTo $WebSg -position bottom

    #Allows Web tier to reach App Tier via the APP VIP and then the NAT'd vNIC address of the Edge
    Write-Output "  -> Creating Web to App Tier rules" | timestamp
    $WebToAppVIP = get-nsxfirewallsection $FirewallSectionName | New-NsxFirewallRule -Name "$WebSgName to App VIP" -Source $WebSg -Destination $AppVIP_IpSet -Service $HttpService -Action $AllowTraffic -AppliedTo $WebSg, $AppSg -position bottom
    $ESGToApp = get-NsxFirewallSection $FirewallSectionName | New-NsxFirewallRule -Name "App ESG interface to $AppSgName" -Source $InternalEsg_IpSet -Destination $appSg -service $HttpService -Action $Allowtraffic -AppliedTo $AppSg -position bottom

    #Allows App tier to reach DB Tier directly
    Write-Output "  -> Creating DB Tier rules" | timestamp
    $AppToDb = get-nsxfirewallsection $FirewallSectionName | New-NsxFirewallRule -Name "$AppSgName to $DbSgName" -Source $AppSg -Destination $DbSg -Service $MySqlService -Action $AllowTraffic -AppliedTo $AppSg, $DbSG -position bottom

    Write-Output "  -> Creating default deny rule to $vAppSgName`n" | timestamp
    #Default rule that wraps around all VMs within the topology - application specific DENY ALL
    $vAppDenyAll = get-nsxfirewallsection $FirewallSectionName | New-NsxFirewallRule -Name "$vAppName Default Rule" -Action $DenyTraffic -AppliedTo $vAppSg -position bottom -EnableLogging -tag "$vAppSg"

    Write-Output "Successfully completed the deployment of vApp $vAppName.`n" | timestamp

}

if ( $nukeit -and ( -not $buildnsx ) ) {

    Write-Output "Clean up started..." | timestamp

    Write-Output "  -> Stopping vApp" | timestamp
    Get-VApp | Where-Object {$_.name -eq ($vAppName)} | Stop-VApp -Force -Confirm:$false | out-null
    Write-Output "  -> Removing vApp" | timestamp
    Get-VApp | Where-Object {$_.name -eq ($vAppName)} | Remove-VApp -DeletePermanently -Confirm:$false | out-null

    Write-Output "  -> Deleting edges" | timestamp
    Get-NsxEdge | Where-Object {$_.name -eq ($EdgeName)} | Remove-NsxEdge -Confirm:$false | out-null
    Get-NsxLogicalRouter | Where-Object {$_.name -eq ($LdrName)} | Remove-NsxLogicalRouter -Confirm:$false | out-null
    #Start-Sleep 10

    Write-Output "  -> Deleting DFW rules" | timestamp
    Get-NsxFirewallSection | Where-Object {$_.name -eq ($vAppName)} | Remove-NsxFirewallSection -force -Confirm:$false | out-null

    Write-Output "  -> Deleting security tags" | timestamp
    Get-NsxSecurityTag | Where-Object {$_.name -eq ($vAppName)} | Remove-NsxSecurityTag -Confirm:$false | out-null

    Write-Output "  -> Deleting IP sets" | timestamp
    Get-NsxIpSet | Where-Object {$_.name -eq ($vAppName)} | Remove-NsxIpSet -Confirm:$false | out-null

    Write-Output "  -> Deleting security groups" | timestamp
    Get-NsxSecurityGroup | Where-Object {$_.name -eq ($vAppName)} | Remove-NsxSecurityGroup -Confirm:$false | out-null

    Write-Output "  -> Deleting service definitions" | timestamp
    Get-NsxService | Where-Object {$_.name -eq ($vAppName)} | Remove-NsxService -Confirm:$false | out-null

    Write-Output "  -> Deleting switches" | timestamp
    Get-NsxLogicalSwitch | Where-Object {$_.name -eq ($TransitLsName)} | Remove-NsxLogicalSwitch -Confirm:$false | out-null
    Get-NsxLogicalSwitch | Where-Object {$_.name -eq ($WebLsName)} | Remove-NsxLogicalSwitch -Confirm:$false | out-null
    Get-NsxLogicalSwitch | Where-Object {$_.name -eq ($AppLsName)} | Remove-NsxLogicalSwitch -Confirm:$false | out-null
    Get-NsxLogicalSwitch | Where-Object {$_.name -eq ($DbLsName)} | Remove-NsxLogicalSwitch -Confirm:$false | out-null
    Get-NsxLogicalSwitch | Where-Object {$_.name -eq ($MgmtLsName)} | Remove-NsxLogicalSwitch -Confirm:$false | out-null

    Write-Output "Clean up finished.`n" | timestamp

}
