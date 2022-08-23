function Get-ASTTree{
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
        $command=@("-Xclang","-ast-dump=json","-fsyntax-only","-nobuiltininc","-Wno-parentheses-equality")
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
            return ConvertFrom-Json ($Result -join "`n")
        }
        
    }
}

function Get-AllVarDecl{
    param(
        [parameter(ValueFromPipeline)]
        [PSCustomObject]
        $Tree
    )
    process{
        
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
function Get-FlattenFile{
    param(
        [Parameter(ValueFromPipeline)]
        [string]
        $FlattenFolder,
        $FileName
    )
    process{

    }
}
function Out-FlattenCollection{
    param($FilePath)
    process{
        ConvertTo-Json -InputObject $Script:FlattenDestHash|Out-File $FilePath -Force
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