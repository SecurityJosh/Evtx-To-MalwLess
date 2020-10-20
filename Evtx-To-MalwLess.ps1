﻿param (
   [Parameter(Mandatory=$true)] [string] $EventFile,
   [Parameter(Mandatory=$true)] [string] $OutputFile = "MalwLess_rules.json"
 )

# https://stackoverflow.com/a/47779605

if(!(Test-Path $EventFile)){
   Write-Host "[!] Error, $EventFile not found"
   return
} 

function Get-EventCategory{
   param(
      $EventDescription,
      $EventId
   )

   # PowerShell
   if($EventId -eq "4103" -or $EventId -eq "4104"){
      return $EventId
   }

   #Sysmon
   if($EventDescription -match '(.*) \(rule:'){
      return $Matches[1]
   }
}

function New-Payload{
   param(
      [System.Xml.XmlElement]$EventData
   )

   $Payload = @{};

   $EventData.ChildNodes | ForEach-Object {
      $Payload = $Payload + @{$_.Name = $_.InnerText} 
   }

   return $Payload

}

function Get-Source{
   param(
      [string]
      $EventProvider
   )
   
   return @{
      "Microsoft-Windows-Sysmon" = "Sysmon";
      "Microsoft-Windows-Powershell" = "PowerShell"
   }[$EventProvider];

}

function Get-MalwLessRule {
   param(
      $EventLog
   )

   [xml] $parsedEventLog =  $EventLog.ToXml();
  
   $ruleTemplate = @{
   "$(Get-Random)" = @{
      "enabled" =  $true;
      "source" =  (Get-Source $_.ProviderName);
      "category" =  "$(Get-EventCategory $EventLog.TaskDisplayName $EventLog.Id)";
      "description" = "$($EventLog.TaskDisplayName)";
      "payload" = $(New-Payload $parsedEventLog.Event.EventData)
    }
   };
  
   return $ruleTemplate;
}

function Get-MalwLessConfig {
   param (
      $Events
   )

   Write-Host "[*] .Evtx file contains $($Events.Count) events"
   
   $Events = $Events | Where-Object {$_.ProviderName -eq "Microsoft-Windows-Sysmon" -or ($_.ProviderName -eq "Microsoft-Windows-Powershell" -and ($_.Id -eq "4103" -or $_.Id -eq "4104"))} 

   Write-Host "[*] .Evtx file contians $($Events.Count) supported events"

   if($Events.Count -eq 0){
      Write-Host "[!] Error - No supported events found"
      return
   }

   $Rules = @{};

   for($i = $Events.Count -1; $i -ge 0; $i--){
      $Rules = $Rules + (Get-MalwLessRule $Events[$i])
   }

   return @{
      "name" = "Auto-Generated";
      "version" = "0.1";
      "author" = "SecurityJosh";
      "description" = "Generated by Evtx-To-Malwless";
      "rules" = $Rules
   } | ConvertTo-Json -Depth 10 | %{
      [Regex]::Replace($_, 
          "\\u(?<Value>[a-zA-Z0-9]{4})", {
              param($m) ([char]([int]::Parse($m.Groups['Value'].Value,
                  [System.Globalization.NumberStyles]::HexNumber))).ToString() } )}
}

Write-Host "[*] Reading from $EventFile"

$Events = Get-WinEvent -Path $EventFile

(Get-MalwLessConfig ($Events)) | Out-File -FilePath $OutputFile -Encoding utf8

Write-Host "[*] MalwLess file written to $OutputFile"