function Test-ASTTree{
    param(
        [parameter(ValueFromPipeline)]
        [string]
        $SourceFile,
        [string[]]
        $HeaderFiles,
        [string[]]
        $IncludeDirs,
        [string[]]
        $PreDefineHeaders
    )
    begin{
        $MatchRegular="(?m)((^In file included from (?<tracefile>[a-zA-Z\:_0-9\\ \t\./])*\:(?<traceline>[0-9]*)\:(?<tracecol>[0-9]*))$[\n])*^(?<filePath>[a-zA-Z\:_0-9\\ \t\./]*)\:(?<line>[0-9]*)\:(?<col>[0-9]*)\:(?<desc>[a-zA-Z\:_0-9\\ \t\./\- '`"&\!\=;\[\]\(\)*,]+)$"
    }
    process{
        $command=@("-Xclang","-ast-dump","-fsyntax-only","-nobuiltininc")#,"-Wno-parentheses-equality")
        if($HeaderFiles){
            # Create Temporary File and store object in $T
            $File = New-TemporaryFile

            # Remove the temporary file .... Muah ha ha ha haaaaa!
            Remove-Item $File -Force

            # Make a new folder based upon the old name
            New-Item -Itemtype Directory -Path "$($File.FullName)" 
            $directory=$File.FullName
            # New-Item -ItemType Directory -Path($directory)
            foreach ($currentItemName in $HeaderFiles) {
                Copy-Item -Path $currentItemName -Destination "$directory\"
               
            }
            $command+="-I`"$directory`""
            
        }
        if($IncludeDirs){
            foreach ($currentItemName in $IncludeDirs) {
                $command+="-I$currentItemName"
            }
        }
        if($PreDefineHeaders){
            foreach ($currentItemName in $PreDefineHeaders) {
                $command+="-include$currentItemName"
            }
        }
        # $clang="C:\Program Files\LLVM\bin\clang.exe"
        $command+="`"$SourceFile`"" 
        $Result= (&"clang" $command *>&1)
        $errorList=$Result|Where-Object{$_.GetType() -eq [System.Management.Automation.ErrorRecord]}
        if($errorList){
            $errorContent=$errorList -join "`n"
            $matchResult=$errorContent|Select-String -Pattern $MatchRegular -AllMatches
            $grantedStatus=$true
            $validated=$false
            for ($i = 0; $i -lt $matchResult.Matches.Count; $i++) {
                $validated=$true
                $detail=""
                if($i -eq $matchResult.Matches.Count-1){
                    $detail=$errorContent.Substring($matchResult.Matches[$i].Index+$matchResult.Matches[$i].Length)
                }
                else{
                    $endlocation=$matchResult.Matches[$i].Index+$matchResult.Matches[$i].Length
                    $detail=$errorContent.Substring($endlocation,$matchResult.Matches[$i+1].Index-$endlocation)
                }
                $traceFiles=@()
                if($matchResult.Matches[$i].Groups["tracefile"].Success){
                    for($j=0;$j-lt $matchResult.Matches[$i].Groups["tracefile"].Captures.Count;$j++){
                        $tracefile=$matchResult.Matches[$i].Groups["tracefile"].Captures[$j].Value
                        $traceLine=0
                        $traceCol=0
                        if([string]::IsNullOrEmpty($matchResult.Matches[$i].Groups["traceline"].Captures[$j].Value)){
                            $traceLine=[int]$matchResult.Matches[$i].Groups["traceline"].Captures[$j].Value
                        }
                        if([string]::IsNullOrEmpty($matchResult.Matches[$i].Groups["tracecol"].Captures[$j].Value)){
                            $traceCol=[int]$matchResult.Matches[$i].Groups["traceline"].Captures[$j].Value
                        }                        
                        $traceFiles+=[PSCustomobject]@{
                            Tracefile=$tracefile
                            TraceLine=$traceLine
                            TraceCol=$traceCol
                        }
                    }
                }
                if(Grant-ASTTreeTestWarning `
                    -Src $SourceFile `
                    -FilePath $matchResult.Matches[$i].Groups["filePath"].Value `
                    -Line $matchResult.Matches[$i].Groups["line"].Value `
                    -Col $matchResult.Matches[$i].Groups["col"].Value `
                    -Desc $matchResult.Matches[$i].Groups["desc"].Value `
                    -Detail $detail `
                    -Traces $traceFiles
                    ){
                    # Write-Host ("Granted:`n$($matchResult.Matches[$i])`n") -ForegroundColor Yellow
                    
                }
                else{
                    Write-Host ("$($matchResult.Matches[$i]) $detail `n") -ForegroundColor Red
                    $grantedStatus=$false
                }
                
            }
            if(-not $grantedStatus -or -not  $validated){
                Write-Error "$SourceFile not granted."
                return $false
            }
        }
        else{
            return $True
        }
        
    }
}
function Grant-ASTTreeTestWarning{
    param(
        [string]
        $FilePath,
        [int]
        $Line,
        [int]
        $Col,
        [string]
        $Desc,
        [string]
        $Detail,
        [string]
        $Src,
        [array]
        $Traces
    )
    process{
        $matchHash=@(
            @{ErrorRegular="";SrcMatch="";Desc=""},
            @{ErrorRegular="";SrcMatch="";Desc=""}
        )
        $ignoreErrors=@(
            "warning",
            "note:",
            "GCC does not allow 'always_inline' attribute",
            "[-Wnonportable-include-path]",
            "[-Wpointer-to-int-cast]",
            "[-Wincompatible-pointer-types-discards-qualifiers]",
            "[-Wint-conversion]",
            "[-Wcomment]",
            "[-Wparentheses]",
            # "& has lower precedence than !=; != will be evaluated first",
            "McalLib_Cfg.h",
            "McalLib_cfg.h"
            # "GCC does not allow 'noreturn' attribute in this position on a function definition",
            # "cast to 'volatile uint32  *' (aka 'volatile unsigned long *') from smaller integer type 'uint32' (aka 'unsigned long')"
        )
        foreach ($currentItemName in $ignoreErrors) {
            if($Desc.Contains($currentItemName)){
                return $true
            }
        }        
        return $false
    }
}

function Out-ASTTree{
    param(
        [parameter(ValueFromPipeline)]
        [string]
        $SourceFile,
        [string[]]
        $HeaderFiles,
        [string[]]
        $IncludeDirs,
        [string[]]
        $PreDefineHeaders,
        [string]
        $OutFilePath
    )
    process{
        if(-not $OutFilePath){
            $OutFilePath=(New-TemporaryFile).FullName
        }
        # $file=New-TemporaryFile
        $command=@("-SourceFile",$SourceFile,"-OutputFile",$OutFilePath,"-Xclang","-ast-dump","-fsyntax-only","-nobuiltininc","-Wno-parentheses-equality")
        if($HeaderFiles){
            # Create Temporary File and store object in $T
            $File = New-TemporaryFile

            # Remove the temporary file .... Muah ha ha ha haaaaa!
            Remove-Item $File -Force

            # Make a new folder based upon the old name
            New-Item -Itemtype Directory -Path "$($File.FullName)" 
            $directory=$File.FullName
            # New-Item -ItemType Directory -Path($directory)
            foreach ($currentItemName in $HeaderFiles) {
                Copy-Item -Path $currentItemName -Destination "$directory\"
               
            }
            $command+="-I`"$directory`""
            
        }
        if($IncludeDirs){
            foreach ($currentItemName in $IncludeDirs) {
                $command+="-I$currentItemName"
            }
        }
        if($PreDefineHeaders){
            foreach ($currentItemName in $PreDefineHeaders) {
                $command+="-include$currentItemName"
            }
        }
        $scriptPath=Resolve-Path $PSScriptRoot/../Files/PyScript/CodeAnalyzer/CommandLineIF.py
        $Result=&"python" "$scriptPath" $command *>&1 
        if($Result|Where-Object{$_.GetType() -eq [System.Management.Automation.ErrorRecord]}){
            Write-Error (($Result|Where-Object{$_.GetType() -eq [System.Management.Automation.ErrorRecord]}) -join "`n") -ErrorAction Stop
        }
        else{
            # return ConvertFrom-Json (Get-Content $OutFilePath -Raw)
            return $OutFilePath
        }
        
    }
}
$Script:CurrentHashMinus=-2
function Get-AllFlattenIndexEntry{
    process{
        (Get-CurrentFlattenCollection).Values
    }
}
function Optimize-FlattenIndex{
    param(
        [parameter(ValueFromPipeline)]
        [PSCustomObject]
        $ASTTree,
        [hashtable]
        $CurrentCollection=@{},
        [Int64]
        $ParentId=-1
    )
    process{
        if($CurrentCollection.Keys.Count -eq 0){
            $Script:CurrentHashMinus=-2
        }
        $hash=$ASTTree.id
        if(-not $ASTTree.id){
            $hash=$Script:CurrentHashMinus--
        }
        if($hash -lt 0 -and $CurrentCollection.ContainsKey($hash)){
            Write-Error "Duplicate hash value $ASTTree"
        }
        $CurrentCollection[$hash]=$ASTTree
        $ASTTree|Add-Member -MemberType NoteProperty -Name 'parentId' -Value $ParentId
        if($ASTTree.inner){
            $ASTTree.inner|ForEach-Object{
                Optimize-FlattenIndex -ASTTree $_ -CurrentCollection $CurrentCollection -ParentId $ASTTree.id|Out-Null
            }
        }        
        return $CurrentCollection
    }
}
function Get-FlattenedCollection{
    param(
        [parameter(ValueFromPipeline)]
        [string]
        $FilePath
    )
    process{
        $ASTTree=ConvertFrom-Json (Get-Content $FilePath -Raw)
        Optimize-FlattenIndex -ASTTree $ASTTree
    }
}
function Find-IndexInFlatten{
    param(
        [parameter(Mandatory,ValueFromPipeline)]
        [Int64]
        $Id
    )
    process{
        (Get-CurrentFlattenCollection)[$Id]
    }
}
function Confirm-FileInDirs{
    param(
        [string[]]
        $Dirs,
        [parameter(ValueFromPipeline)]
        [string]
        $FilePath
    )
    begin{
        $dirPaths=@()
        if($Dirs -and $Dirs.Count -gt 0){
            $dirPaths=$Dirs|ForEach-Object{Resolve-Path $_}|ForEach-Object{$_.Path}
        }       
    }
    process{
        $filePathAll=(Resolve-Path $FilePath).Path
        if($dirPaths.Count -eq 0){
            return $ture
        }
        elseif($dirPaths|Where-Object{$filePathAll.StartsWith($_)}|Select-Object -First 1){
            return $true
        }
        else{
            return $false
        }
    }
}
function Test-LocalVariable{
    param(
        [parameter(Mandatory,ValueFromPipeline)]
        [Int64]
        $Id
    )
    process{
        $currentId=$Id        
        while($currentId -ne -1){
            $currentId=(Get-CurrentFlattenCollection)[$currentId].parentId
            if((Get-CurrentFlattenCollection)[$currentId].kind -eq "FUNCTION_DECL"){
                return $true
            }
        }
        return $false
    }
}

# key: source file
$Script:FlattenDestHash=@{

}
function Clear-FlattenFiles{
    param(
        [string[]]
        $Dest
    )
    process{
        if($Dest){
            $Dest|ForEach-Object{
                if($Script:FlattenDestHash.ContainsKey($Dest)){
                    $Script:FlattenDestHash.Remove($_)
                    Remove-Item $_ -Force -Recurse
                }
                else{
                    Write-Error "$_ not exisiting in Flatten files."
                }
            }
        }
        else{
            $Script:FlattenDestHash.Keys|ForEach-Object{
                Remove-Item $_ -Force -Recurse
            }
            $Script:FlattenDestHash=@{}
        }
    }
}
function Out-FlattenFilesCollection{
    param(
        [string]
        $Dest
    )
    process{
        if(Test-Path $Dest){
            if(Test-Path ("$Dest.bak")){
                Remove-Item "$Dest.bak" -Force
            }
            Rename-Item -Path $Dest -NewName "$Dest.bak" -Force
        }
        ConvertTo-Json -InputObject $Script:FlattenDestHash|Out-File -Path $Dest
    }
}
function Get-FlattenFilesCollection{
    param($FilePath)
    process{
        $fileConfig=[PSCustomObject]@{
            
        }
        if(Test-Path $FilePath){
            $fileConfig=ConvertFrom-Json -InputObject (Get-Content $FilePath -Raw) -Depth 5
        }        
        $fileConfig.PSObject.Properties|ForEach-Object{
            $storagePath=$_.Name
            if(Test-Path $_.Name){

            }
            else{
                $_.Value.Mapping.PSObject.Properties|ForEach-Object{
                    Copy-Item -Path $_.Value -Destination $storagePath -Force
                }
            }
            $Script:FlattenDestHash[$_.Name]=$_.Value
            
        }

    }
}
function Use-FlattenFiles{
    param(
        # Parameter help description
        [Parameter(ValueFromPipeline)]
        [string]
        $RootFolder,
        [scriptblock]
        $ReturnFilter={return $true},
        [scriptblock]
        $FolderFilter={return $true},
        [switch]
        $Force,
        [string]
        $Dest
    )
    process{
        # $ResultContainerPair=$Script:FlattenDestHash.Keys|Where-Object{$Script:FlattenDestHash[$_].Src -eq $RootFolder}|Select-Object -First 1
        # $ResultContainer=$null
        # if($ResultContainerPair){
        #     if($Force){
        #         Clear-FlattenFiles $Script:FlattenDestHash[$ResultContainerPair]
        #     }
        #     $ResultContainer=$Script:FlattenDestHash[$ResultContainerPair]
        # }
        # else{
            
        # }
        if(-not $Dest){
            $Dest=(New-TemporaryDirectory).FullName
        }
        # if(-not $ResultContainer){
            if(Test-Path $Dest){
                Remove-Item "$Dest\*" -Recurse -Force -Verbose
            }
            $ResultContainer=@{
                Mapping = @{}
                Dest=$Dest
                Src=$RootFolder
            }
            $RootFolder|Get-ChildItemAdvance -ReturnFilter $ReturnFilter -FolderFilter $FolderFilter|ForEach-Object{
                if($ResultContainer.Mapping.ContainsKey($_.Name)){
                    Write-Error "$($_.FullName) Duplicate with $($ResultContainer.Mapping[$_.Name])"
                }
                else{
                    $ResultContainer.Mapping[$_.Name]=$_.FullName
                    Copy-Item -Path $_ -Dest $ResultContainer.Dest -Force -Verbose
                }            
            }
            # $Script:FlattenDestHash[$ResultContainer.Dest]=$ResultContainer
        # }        
        return $ResultContainer.Dest
    }
    end{
    }
}
function Export-UsedSymbolInfo{
    param(
        [parameter(ValueFromPipeline)]
        $SymbolUsedDefined
    )
    process{
        return [PSCustomObject]@{
            Symbol=$SymbolUsedDefined.name
            Id=$SymbolUsedDefined.id
            ASTLocation=Get-CurrentASTLocation
        }
    }
}
function Get-AllUsedExternVariable{
    process{
        Get-AllFlattenIndexEntry|
        Where-Object{$_.kind -eq "DECL_REF_EXPR"}|
        Where-Object{($_.reference|Find-IndexInFlatten).kind -eq "VAR_DECL"}|
        Where-Object{-not ($_.reference|Test-LocalVariable)}|
        Where-Object{$_.location|Confirm-FileInDirs -Dirs $DirObjs}|
        Where-Object{($_.reference|Find-IndexInFlatten).storage -eq "EXTERN"}
    }
}
function Get-CurrentASTLocation{
    process{
        $Script:CurrentFlattenCollectionStack[-1]
    }
}
function Get-CurrentFlattenCollection{
    process{
        $Script:CurrentASTFlattenHashTable[$Script:CurrentFlattenCollectionStack[-1]]
    }
}
function Get-RelativePath{
    param (
        [parameter(ValueFromPipeline)]
        [string]
        $Path,
        [parameter(Position=0)]
        [string]
        $RootPath
    )
    process{
        [System.IO.Path]::GetRelativePath($RootPath,$Path)
        # $Path=Get-FullPath -FileName $Path
        # if((-not $RootPath.EndsWith("\") )-or (-not $RootPath.EndsWith("/"))){
        #     $RootPath+="\"
        # }
        # $RootPath=Get-FullPath -FileName $RootPath
        # return ($Path.Substring($RootPath.Length))
    }
    
}
$Script:CurrentASTFlattenHashTable=@{}

$Script:CurrentFlattenCollectionStack=[System.Collections.ArrayList]@()
function Use-FlattenCollection{
    param(
        [Parameter(ValueFromPipeline)]
        $FilePath,
        [parameter(Position=0)]
        [scriptblock]
        $Process
    )
    process{
        # add user file into stack
        $Script:CurrentFlattenCollectionStack.Add($FilePath)
        if(-not $Script:CurrentASTFlattenHashTable.ContainsKey($FilePath)){
            $Script:CurrentASTFlattenHashTable[$FilePath]=$FilePath|Get-FlattenedCollection
        }
        &$Process
        $Script:CurrentFlattenCollectionStack.RemoveAt($Script:CurrentFlattenCollectionStack.Count-1)
    }
}
function Confirm-ExternFunction{
    param(
        [parameter(ValueFromPipeline)]
        $Id
    )
    process{
        if((Get-CurrentFlattenCollection)[$Id].inner|Where-Object{
            $_.kind -eq "COMPOUND_STMT"
        }|Select-Object -First 1){
            return $false
        }
        else{
            return $true
        }
    }
}
<#
.SYNOPSIS
    Find all global variables that been declared in this AST Tree
.DESCRIPTION
    A longer description of the function, its purpose, common use cases, etc.
.NOTES
    Information or caveats about the function e.g. 'This function is not supported in Linux'
.LINK
    Specify a URI to a help page, this will show when Get-Help -Online is used.
.EXAMPLE
    Test-MyTestFunction -Verbose
    Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
#>
function Get-AllGlobalVariables{
    param(
        [string[]]
        $FilesAllowDirs
    )
    process{
        Get-AllFlattenIndexEntry|
        Where-Object{-not [string]::IsNullOrEmpty($_.location)}|
        Where-Object{$_.location|Confirm-FileInDirs -Dirs $FilesAllowDirs}|
        Where-Object{($_).kind -eq "VAR_DECL"}|
        Where-Object{-not ($_.id|Test-LocalVariable)}|
        Where-Object{($_).storage -ne "EXTERN" -and ($_).storage -ne "STATIC"}
    }
}
function Get-AllGlobalFunctions{
    param(
        [string[]]
        $FilesAllowDirs
    )
    process{
        Get-AllFlattenIndexEntry|
        Where-Object{-not [string]::IsNullOrEmpty($_.location)}|
        Where-Object{$_.location|Confirm-FileInDirs -Dirs $FilesAllowDirs}|
        Where-Object{($_).kind -eq "FUNCTION_DECL"}|
        Where-Object{-not ($_.id|Confirm-ExternFunction)}
    }
}
function Get-AllUsedExternFunctions{
    param(
        [string[]]
        $FilesAllowDirs
    )
    process{
        Get-AllFlattenIndexEntry|
        Where-Object{$_.kind -eq "DECL_REF_EXPR"}|
        Where-Object{($_.reference|Find-IndexInFlatten).kind -eq "FUNCTION_DECL"}|
        Where-Object{($_.reference|Confirm-ExternFunction)}|
        Where-Object{($_.reference|Find-IndexInFlatten).location|Confirm-FileInDirs -Dirs $FilesAllowDirs}|
        ForEach-Object{($_.reference)}|Select-Object -Unique|Find-IndexInFlatten
    }
}

<#
.SYNOPSIS
    Find all extern variables that has been used in this C file
.DESCRIPTION
    A longer description of the function, its purpose, common use cases, etc.
.NOTES
    Information or caveats about the function e.g. 'This function is not supported in Linux'
.LINK
    Specify a URI to a help page, this will show when Get-Help -Online is used.
.EXAMPLE
    Test-MyTestFunction -Verbose
    Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
#>
function Get-AllExternVariables{
    param(
        [string[]]
        $FilesAllowDirs
    )
    process{
        Get-AllFlattenIndexEntry|
        Where-Object{$_.kind -eq "DECL_REF_EXPR"}|
        Where-Object{($_.reference|Find-IndexInFlatten).kind -eq "VAR_DECL"}|
        Where-Object{-not ($_.reference|Test-LocalVariable)}|
        Where-Object{$_.location|Confirm-FileInDirs -Dirs $FilesAllowDirs}|
        Where-Object{($_.reference|Find-IndexInFlatten).storage -eq "EXTERN"}|
        ForEach-Object{($_.reference)}|Select-Object -Unique|Find-IndexInFlatten
    }
}

function Get-AllVisibleVariables{
    param(
        [string[]]
        $FilesAllowDirs
    )
    process{
        [PSCustomObject]@{
            
            Extern=Get-AllExternVariables -FilesAllowDirs $FilesAllowDirs|Export-UsedSymbolInfo
            GlobalVariables=Get-AllGlobalVariables -FilesAllowDirs $FilesAllowDirs|Export-UsedSymbolInfo
        }
    }
}
function Get-AllVisibleFunctions{
    param(
        [string[]]
        $FilesAllowDirs
    )
    process{
        [PSCustomObject]@{
            
            Extern=Get-AllUsedExternFunctions -FilesAllowDirs $FilesAllowDirs|Export-UsedSymbolInfo
            Global=Get-AllGlobalFunctions -FilesAllowDirs $FilesAllowDirs|Export-UsedSymbolInfo
        }
    }
}
function Merge-Definitions{
    param(
        [PSCustomObject[]]
        $Definitions
    )
    process{
        $GlobalVariableDefinitionHash=@{

        }
        $VariableDefinitions|Select-Object -ExpandProperty Global|ForEach-Object{
            $GlobalVariableDefinitionHash[$_.Symbol]=$_
        }
        [PSCustomObject]@{
            Global=$GlobalVariableDefinitionHash.Values
            Extern=$VariableDefinitions|Select-Object -ExpandProperty Extern|Where-Object{
                -not $GlobalVariableDefinitionHash.ContainsKey($_.Symbol)
            }
        }
        
    }
}