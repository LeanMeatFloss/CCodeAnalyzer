BeforeAll{
    $env:PSModulePath+=[IO.Path]::PathSeparator+(Resolve-Path "$PSScriptRoot/..")
    $env:Path+=[IO.Path]::PathSeparator+(Resolve-Path "C:\Program Files\LLVM\bin")
    $moduleName=(([System.IO.DirectoryInfo] (Resolve-Path "$PSScriptRoot").Path).Name)
    $RepoRoot=Resolve-Path "$PSScriptRoot/../../"
    Write-Host "Test Module Name $moduleName"
    Import-Module $moduleName -Force
}
Describe "Get-ASTTree"{
    It "Read C Code Parser Example 01"{
        $SourceFilePath=Resolve-Path "$RepoRoot/Resources/TestResources/CCodeExample01/Hello.c"
        $HeaderFilePath=Resolve-Path "$RepoRoot/Resources/TestResources/CCodeExample01/Hello.h"
        $Tree=Get-ASTTree -SourceFile $SourceFilePath -HeaderFiles $HeaderFilePath
        ($Tree.inner|Where-Object {$_.kind -eq "VarDecl"}).Count |Should -Be 2
    }
    It "Read C Code Parser Example 02"{
        $SourceFilePath=Resolve-Path "$RepoRoot/Resources/TestResources/CCodeExample02/Hello.c"
        $HeaderFilePath=Resolve-Path "$RepoRoot/Resources/TestResources/CCodeExample02/Hello.h"
        $Tree=Get-ASTTree -SourceFile $SourceFilePath -HeaderFiles $HeaderFilePath
        ($Tree.inner|Where-Object {$_.kind -eq "VarDecl"}).Count |Should -Be 3
    }
    It "Read C Code Parser Example 03"{
        $SourceFilePath=Resolve-Path "Z:\BRM2_8\P200_Dev\P200_SW_Dev\P200_SW\pf\01_AppLyr\Sys_Ctrl\ADtRp\src\ADtRp_Report_cc.c"
        
        # get all include files path from the make script.
        $blackList=Get-Content "Z:\BRM2_8\P200_Dev\P200_SW_Dev\P200_SW\pf\Tools_cfg\swBuild\HFiles_BlackList.txt"|Select-String -AllMatches -Pattern "(?m)^\$\(WorkspacePath\)\\"|ForEach-Object{
            Join-Path "Z:\BRM2_8\P200_Dev\P200_SW_Dev\P200_SW" ($_.ToString().Replace("`$(WorkspacePath)\",""))
        }
        $piorityHeaderFiles=New-TemporaryDirectory
        $DirPath=@(
            $piorityHeaderFiles
            # (Resolve-Path "Y:\100_ArxmlContGen\P200\P200_V365\CPG_Output\ADtRp")

        )
        $testCode=@"
#ifndef RTE_INSTANCECONSTP2CONST
#define RTE_INSTANCECONSTP2CONST(arg1, arg2, arg3) arg1
#endif
"@
        $targetFile=(Join-Path $piorityHeaderFiles "PreDefinedMarco.h")
        $testCode|Out-File $targetFile
        # flatten the header files
        $headerFileDir=New-TemporaryDirectory
        # New-Item -Path $headerFileDir -Itemtype Directory
        $headerFileHash=@{}
        "Y:\100_ArxmlContGen\P200\P200_V365\CPG_Output\ADtRp"|Get-ChildItemAdvance -ReturnFilter {$_.Extension -eq ".h"}|Copy-Item  -Dest $piorityHeaderFiles -Verbose
        "Z:\BRM2_8\P200_Dev\P200_SW_Dev\P200_SW\pf"|Get-ChildItemAdvance -FolderFilter {
            $file=$_
            -not ($blackList|Where-Object{
                $file.FullName.StartsWith($_)
            }|Select-Object -First 1)
        } -ReturnFilter{
            $file=$_
            ($_.Extension -eq '.h')-and (-not ($blackList|Where-Object{
                $file.FullName.StartsWith($_)
            }|Select-Object -First 1))
        }|ForEach-Object{
            if($headerFileHash.ContainsKey($_.Name)){
                Write-Error "$($_.FullName) Duplicate with $($headerFileHash[$_.Name])"
            }
            else{
                $headerFileHash[$_.Name]=$_.FullName
                return $_              
            }
        }|ForEach-Object{
            # comment out 
            if($_.Name.Contains("MemMap")){
                $content=Get-Content -Path $_.FullName -Raw
                $content=$content.Replace("# pragma section","//# pragma section")
                
                $content|Out-File (Join-Path $headerFileDir $_.Name)
            }
            elseif($_.Name -eq "Rte_Type.h"){
                Copy-Item -Path $_ -Dest $piorityHeaderFiles -Verbose -Force
            }
            else{
                return $_                
            }            
        }|Copy-Item  -Dest $headerFileDir -Verbose
        # Get-ChildItem "Z:\BRM2_8\P200_Dev\P200_SW_Dev\P200_SW\pf" -Filter "*.h" -Recurse|Where-Object{
        #     $file=$_
        #     -not ($blackList|Where-Object{
        #         $file.FullName.StartsWith($_)
        #     }|Select-Object -First 1)
        # }|Foreach-Object{
        #     if($headerFileHash.ContainsKey($_.Name)){
        #         Write-Error "$($_.FullName) Duplicate with $($headerFileHash[$_.Name])"
        #     }
        #     else{
        #         $headerFileHash[$_.Name]=$_.FullName
        #         return $_                
        #     }
        # }|ForEach-Object{
        #     $content=Get-Content -Path $_.FullName -Raw
        #     # comment out 
        #     $content.Replace("# pragma section","//# pragma section")
        #     $content|Out-File (Join-Path $headerFileDir $_.Name)
        # }
        $DirPath+=$headerFileDir
        # $HeaderFiles=@(            
        #     "Z:\BRM2_8\P200_Dev\P200_SW_Dev\P200_SW\pf\03_SrvLyr\SysSrv\StdT\cfg\Cfg_Output\manual\Std_Types.h" ,
        #     "Z:\BRM2_8\P200_Dev\P200_SW_Dev\P200_SW\pf\03_SrvLyr\SysSrv\StdT\cfg\Cfg_Output\manual\Platform_Types.h", 
        #     "Z:\BRM2_8\P200_Dev\P200_SW_Dev\P200_SW\pf\03_SrvLyr\SysSrv\StdT\cfg\Cfg_Output\manual\Compiler.h",
        #     "Z:\BRM2_8\P200_Dev\P200_SW_Dev\P200_SW\pf\03_SrvLyr\SysSrv\StdT\cfg\Cfg_Output\manual\Compiler_Cfg.h",
        #     "Z:\BRM2_8\P200_Dev\P200_SW_Dev\P200_SW\pf\03_SrvLyr\MemSrv\MemMap\cfg\Cfg_Output\manual\MemMap.h"
        # )
        $Tree=Get-ASTTree -SourceFile $SourceFilePath -IncludeDirs $DirPath -PreDefineHeaders $targetFile
        ($Tree.inner|Where-Object {$_.kind -eq "VarDecl"}).Count |Should -Be 2
        $isUsed=$Tree.inner|Where-Object{$_.isUsed}
    }
}