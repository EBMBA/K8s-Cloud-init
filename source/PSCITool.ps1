#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
[Void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework') 
foreach ($item in $(gci .\source\assembly\ -Filter *.dll).name) {
    [Void][System.Reflection.Assembly]::LoadFrom("source\assembly\$item")
}
#########################################################################
#                        Import Module                                  #
#########################################################################
$path = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

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

$Form.ShowDialog() | Out-Null

