param(
    [Parameter(ValueFromPipeline,Mandatory)]
    [string]
    $ModuleName
)
$initLocation=Get-Location
$gitUrl=(git remote get-url --all origin)
Write-Host "Current git url is $gitUrl"
$gitRepoName=($gitUrl.replace(".git","") -split "/")[-1]
Write-Host "Current git repo name is $gitRepoName"
$moduleBaseName=$gitRepoName.Replace("-","")
Write-Host "Current module base name $moduleBaseName"
$gitHostName=($gitUrl.replace(".git","") -split "/")[-2]


Set-Location "$PSScriptRoot/../"
New-Item -Path "./$moduleBaseName/$moduleBaseName-$ModuleName" -ItemType Directory -Force
New-Item -Path "./$moduleBaseName/$moduleBaseName-$ModuleName/$moduleBaseName-$ModuleName.Tests.ps1" -ItemType File -Force
New-Item -Path "./$moduleBaseName/$moduleBaseName-$ModuleName/Module" -ItemType Directory -Force
New-Item -Path "./$moduleBaseName/$moduleBaseName-$ModuleName/Module/$moduleBaseName-$ModuleName.psm1" -ItemType File -Force
# New-Item -Path "./$moduleBaseName/$moduleBaseName-$ModuleName/Script" -ItemType Directory -Force
# New-Item -Path "./$moduleBaseName/$moduleBaseName-$ModuleName/Script/$moduleBaseName-$ModuleName.Classes.ps1" -ItemType File -Force
New-ModuleManifest -Description "$moduleBaseName"  -Path "./$moduleBaseName/$moduleBaseName-$ModuleName/$moduleBaseName-$ModuleName.psd1" -Author "LeanMeatFloss" -CompanyName "Song" -Copyright @"
MIT License

Copyright (c) 2022 Hansong Li

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@ -FunctionsToExport ("*") -CmdletsToExport ("*") -LicenseUri "https://raw.githubusercontent.com/$gitHostName/$gitRepoName/main/LICENSE" -RootModule "Module/$moduleBaseName-$ModuleName.psm1"  -NestedModules "$moduleBaseName-Basic"
Set-Location $initLocation