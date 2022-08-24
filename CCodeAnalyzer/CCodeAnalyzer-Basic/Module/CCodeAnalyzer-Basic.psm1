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
    process{
        $command=@("-Xclang","-ast-dump","-fsyntax-only","-nobuiltininc","-Wno-parentheses-equality")
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
        $Result= &"clang" $command *>&1
        if($Result|Where-Object{$_.GetType() -eq [System.Management.Automation.ErrorRecord]}){
            Write-Error (($Result|Where-Object{$_.GetType() -eq [System.Management.Automation.ErrorRecord]}) -join "`n") -ErrorAction Stop
        }
        else{
            
        }
        
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
        $dirPaths=$Dirs|ForEach-Object{Resolve-Path $_}|ForEach-Object{$_.Path}
       
    }
    process{
        $filePathAll=(Resolve-Path $FilePath).Path
        if($dirPaths|Where-Object{$filePathAll.StartsWith($_)}|Select-Object -First 1){
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
function Get-FlattenFilesCollection{
    param($FilePath)
    process{
        $fileConfig=ConvertFrom-Json -InputObject (Get-Content $FilePath -Raw) -Depth 5
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
        [scriptblock]
        $PostProcess
    )
    process{
        $ResultContainerPair=$Script:FlattenDestHash.Keys|Where-Object{$Script:FlattenDestHash[$_].Src -eq $RootFolder}|Select-Object -First 1
        $ResultContainer=$null
        if($ResultContainerPair){
            if($Force){
                Clear-FlattenFiles $Script:FlattenDestHash[$ResultContainerPair]
            }
            $ResultContainer=$Script:FlattenDestHash[$ResultContainerPair]
        }
        else{
            
        }
        if(-not $ResultContainer){
            $ResultContainer=@{
                Mapping = @{}
                Dest=(New-TemporaryDirectory)
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
            $Script:FlattenDestHash[$ResultContainer.Dest.FullName]=$ResultContainer
        }        
        return $ResultContainer.Dest.FullName
    }
    end{
        if($PostProcess){
            $ResultContainer.Dest|Get-ChildItem -Recurse|ForEach-Object $PostProcess
        }
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
            Id=$SymbolUsedDefined.Id
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
function Get-CurrentFlattenCollection{
    process{
        $collection=$ExecutionContext.SessionState.PSVariable.Get("FlattenCollection")
        $collection.Value
    }
}
function Use-FlattenCollection{
    param(
        [Parameter(ValueFromPipeline)]
        [hashtable]
        $FlattenCollection,
        [parameter(Position=0)]
        [scriptblock]
        $Process
    )
    process{
        $Process.InvokeWithContext($null,@(
            [psvariable]::new("FlattenCollection",$FlattenCollection)
        ),$null)
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

{0}
function Get-AllGlobalVariables{
    param(
        [string[]]
        $FilesAllowDirs
    )
    process{
        Get-AllFlattenIndexEntry|
        Where-Object{($_).kind -eq "VAR_DECL"}|
        Where-Object{-not ($_|Test-LocalVariable)}|
        Where-Object{$_.location|Confirm-FileInDirs -Dirs $FilesAllowDirs}|
        Where-Object{($_|Find-IndexInFlatten).storage -ne "EXTERN" -and ($_|Find-IndexInFlatten).storage -ne "STATIC"}
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

{0}
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
        Where-Object{($_.reference|Find-IndexInFlatten).storage -eq "EXTERN"}
    }
}
function Merge-ExternAndExposed{
    param(
        [hashtable[]]
        $ExposedCollections,
        [hashtable[]]
        $test
    )
    process{

    }
}