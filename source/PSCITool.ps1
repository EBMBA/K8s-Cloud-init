Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

[Void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework') 
foreach ($item in $(gci .\assembly\ -Filter *.dll).name) {
    [Void][System.Reflection.Assembly]::LoadFrom("assembly\$item")
}
#########################################################################
#                        Import Module                                  #
#########################################################################
$path = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

Import-Module powershell-yaml

#########################################################################
#                        Load Main Panel                                #
#########################################################################

$Global:pathPanel= split-path -parent $MyInvocation.MyCommand.Definition

function LoadXaml ($filename){
    $XamlLoader=(New-Object System.Xml.XmlDocument)
    $XamlLoader.Load($filename)
    return $XamlLoader
}
$XamlMainWindow=LoadXaml($pathPanel+"\main.xaml")
$reader = (New-Object System.Xml.XmlNodeReader $XamlMainWindow)
$Form = [Windows.Markup.XamlReader]::Load($reader)



#########################################################################
#                       Functions                       								#
#########################################################################
$XamlMainWindow.SelectNodes("//*[@Name]") | %{
    try {Set-Variable -Name "$("WPF_"+$_.Name)" -Value $Form.FindName($_.Name) -ErrorAction Stop}
    catch{throw}
    }
 
Function Get-FormVariables{
  if ($global:ReadmeDisplay -ne $true){Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow;$global:ReadmeDisplay=$true}
  write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
  get-variable *WPF*
}
  #Get-FormVariables

Function New-MahappsMessage {
  [CmdletBinding()]
  param (
    
    [Parameter(Mandatory=$true)]
    [String]$title,
    [Parameter(Mandatory=$true)]
    [String]$Message
    
  )
  
  $Button_Style = [MahApps.Metro.Controls.Dialogs.MetroDialogSettings]::new()
  $okAndCancel = [MahApps.Metro.Controls.Dialogs.MessageDialogStyle]::Affirmative  
  $result = [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,$title,$Message,$okAndCancel, $Button_Style)   

  
}


function Decode-SecureStringPassword
{
    [CmdletBinding()]
    [Alias('dssp')]
    [OutputType([string])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,                   
                   Position=0) ]     
        $password 
    )
    Begin
    {
    }
    Process
    {        
       return [System.Runtime.InteropServices.Marshal]::PtrToStringUni([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($password))              
    }
    End
    {}
}

# Verifie si le champ est vide ou rempli par des espaces
function Validate-IsEmptyTrim ([string] $field) {

  if($field -eq $null -or $field.Trim().Length -eq 0) {
    return $true    
  }
      
  return $false
}


#Make PowerShell Disappear
#$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
#$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
#$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
 
# Force garbage collection just to start slightly lower RAM usage.
#[System.GC]::Collect()

#########################################################################
#                       Close Buttons                    								#
#########################################################################

$WPF_ExitIP.Add_Click({
  $Form.Close()
})

$WPF_ExitP.Add_Click({
  $Form.Close()
})

#########################################################################
#                       Functionality Buttons            								#
#########################################################################

$WPF_Theme.Add_Click({
  $Theme1 = [ControlzEx.Theming.ThemeManager]::Current.DetectTheme($form)
   $my_theme = ($Theme1.BaseColorScheme)
 If($my_theme -eq "Light")
   {
           [ControlzEx.Theming.ThemeManager]::Current.ChangeThemeBaseColor($form,"Dark")
           $WPF_Theme.ToolTip = "Theme Dark"
   }
 ElseIf($my_theme -eq "Dark")
   {					
           [ControlzEx.Theming.ThemeManager]::Current.ChangeThemeBaseColor($form,"Light")
           $WPF_Theme.ToolTip = "Theme Light"
   }		
})

$WPF_Github.Add_Click({
  start https://github.com/EBMBA
})

#########################################################################
#                       Auto-filling                    								#
#########################################################################
$AvailableCR = @{
  Containerd = @{
    '1.6.1' =@{
      command = (
        "apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common", 
        "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -", 
        'add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"', 
        "apt update -y",
        "apt install -y containerd.io", 
        "mkdir -p /etc/containerd",
        "containerd config default | tee /etc/containerd/config.toml", 
        "systemctl restart containerd"
      )
    }
  }
}

$AvailableKubernetes = @{
  version = ('1.23.3-00')
  '1.23.3-00' = @{
    command = (
      'curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -',
      'echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list',
      'apt update && apt install -y kubeadm=1.23.3-00 kubelet=1.23.3-00 kubectl=1.23.3-00'      
    )
    userConf = (
      'mkdir -p /home/ubuntu/.kube',
      'cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config',
      'chown $(id -u ubuntu):$(id -g ubuntu) /home/ubuntu/.kube/config'
    )
  }
  general = @{
    commandDHCP = (
      'IP_ADDR=$(hostname  -I | cut -f1 -d" ")'
    )
  }
}

$AvailableCNI = @{
  Calico = @{
    command = ('kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://projectcalico.docs.tigera.io/manifests/calico-typha.yaml')
  }
}

$AdditionalSettings = @{
  Helm3 = @{
    command =('curl https://baltocdn.com/helm/signing.asc | apt-key add -', 'apt-get install apt-transport-https --yes', 'echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list', 'apt-get update -y', 'apt-get install helm -y')
  }
  Openssl = @{
    command =('apt install openssl -y')
  }
  UpdatePackage = @{
    package_update = "true"
  }
}

$UselessList = ('True', 'False')

$VisibilitySettings = @{
  Node = @{
    $WPF_SCNI = 'Collapsed'
    $WPF_SPodNetwork = 'Collapsed'
    $WPF_SNetworkMask = 'Collapsed'
    $WPF_SHelm3 = 'Collapsed'
    $WPF_SCertManager = 'Collapsed'
    $WPF_SOpenssl = 'Collapsed'
  }
  Master = @{
    $WPF_SCNI = 'Visible'
    $WPF_SPodNetwork = 'Visible'
    $WPF_SNetworkMask = 'Visible'
    $WPF_SHelm3 = 'Visible'
    $WPF_SCertManager = 'Visible'
    $WPF_SOpenssl = 'Visible'
  }
}

foreach ($CR in $AvailableCR.Keys){
  $WPF_CR.Items.Add($CR) | Out-Null
  foreach ($version in $AvailableCR.$CR.Keys){
    $WPF_CRVersion.Items.Add($version) | Out-Null
  }
}

foreach ($version in $AvailableKubernetes.version){
  $WPF_KVersion.Items.Add($version) | Out-Null
}

foreach ($CNI in $AvailableCNI.Keys){
  $WPF_CNI.Items.Add($CNI) | Out-Null
}

foreach ($item in $UselessList){
  $WPF_Helm3.Items.Add($item) | Out-Null
  $WPF_CertManager.Items.Add($item) | Out-Null
  $WPF_Openssl.Items.Add($item) | Out-Null
  $WPF_UpdatePackage.Items.Add($item) | Out-Null
}

foreach ($type in $VisibilitySettings.Keys){
  $WPF_Type.Items.Add($type) | Out-Null
}

$WPF_CR.SelectedIndex = 0
$WPF_CRVersion.SelectedIndex = 0
$WPF_KVersion.SelectedIndex = 0
$WPF_CNI.SelectedIndex = 0
$WPF_Helm3.SelectedIndex = 0
$WPF_CertManager.SelectedIndex = 0
$WPF_Openssl.SelectedIndex = 0
$WPF_UpdatePackage.SelectedIndex = 0
$WPF_Type.SelectedIndex = 0

#########################################################################
#                       Hidding settings                 								#
#########################################################################
$WPF_Type.add_SelectionChanged({
  $type = $WPF_Type.SelectedItem.ToString()
  foreach ($item in $VisibilitySettings.$($type).Keys){
    $item.Visibility = $VisibilitySettings.$($type).$($item)
  }
})


#########################################################################
#                       Generating File                 								#
#########################################################################
$SettingCommands = [ordered]@{
  Node = @{
    runcmd = @(

    )
  }
  Master = @{

  }
}

$Prerequisites = @{
  command = ('modprobe br_netfilter', "sudo sed -i -e 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf && sudo sysctl -p /etc/sysctl.conf", 'sysctl --system')
}

$WPF_Create.IsEnabled = $True

$WPF_Create.Add_Click({
  # Ordered LIFO for Hashtable 
  # Ordered FIFO for Array (ex runcmd)
  $type = $WPF_Type.SelectedItem.ToString()
 
  # Handle choices true for any kind of deployments
  $KubernetesVersion  =   $WPF_KVersion.SelectedItem.ToString()
  $FQDN   =   $WPF_FQDN.text
  $ContainerRuntime   =   $WPF_CR.SelectedItem.ToString()
  $ContainerRuntimeVersion  =   $WPF_CRVersion.SelectedItem.ToString()

  # Apply prerequisites
  $SettingCommands.$type.runcmd += $Prerequisites.command

  # Install Container Runtime
  $SettingCommands.$type.runcmd += $AvailableCR."$ContainerRuntime"."$ContainerRuntimeVersion".command

  # Install Kubernetes 
  $SettingCommands.$type.runcmd += $AvailableKubernetes."$KubernetesVersion".command

  # Handle choice by kind of deployment
  if ($type -eq "Master") {
    # Master Cloud-Init file
    $ContainerNetworkInterface = $WPF_CNI.SelectedItem.ToString()
    $ContainerPodNetwork = $WPF_PodNetwork.text
    $ContainerNetworkMask = $WPF_NetworkMask.text
    
    # Configure Kubernetes
    $AvailableKubernetes.general.commandDHCP += "kubeadm init --apiserver-advertise-address=`$IP_ADDR --pod-network-cidr=$ContainerPodNetwork/$ContainerNetworkMask  --ignore-preflight-errors=all"
    $SettingCommands.$type.runcmd += $AvailableKubernetes.general.commandDHCP

    # Deploy CNI
    $SettingCommands.$type.runcmd += $AvailableCNI.$ContainerNetworkInterface.command

    # Install Helm    
    if ($($WPF_Helm3.SelectedItem.ToString()) -eq 'True') {
      $SettingCommands.$type.runcmd += $AdditionalSettings.Helm3.command
    }

  }
  # Handle choices true for any kind of deployments

  # User Kubernetes config 
  $SettingCommands.$type.runcmd += $AvailableKubernetes.$KubernetesVersion.userConf

  # Update package   
  $UpdatePackage  =   $WPF_UpdatePackage.SelectedItem.ToString()

  if ($UpdatePackage -eq 'True') {
    $SettingCommands.$type.$($($AdditionalSettings.UpdatePackage.Keys)) = $($($AdditionalSettings.UpdatePackage.Values))
  }

  # Define the Hostname

  # Add Users and Groups

  # Debug console 
  foreach ($key in $SettingCommands.$type.Keys){
    foreach ($value in $SettingCommands.$type.Values){
      Write-Host $key 
      Write-Host $value
    }
 }
  foreach ($items in $SettingCommands.$type.runcmd){
     Write-Host $items
  }
   
})

$Form.ShowDialog() | Out-Null