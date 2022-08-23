function New-TemporaryDirectory{
    process{
        # Create Temporary File and store object in $T
        $File = New-TemporaryFile

        # Remove the temporary file .... Muah ha ha ha haaaaa!
        Remove-Item $File -Force

        # Make a new folder based upon the old name
        $directory=New-Item -Itemtype Directory -Path "$($File.FullName)" 
        return $directory
    }
}
function Get-ChildItemAdvance{
    param(
        [parameter(ValueFromPipeline)]
        [string]
        $Directory,
        [scriptblock]
        $FolderFilter={return $true},
        [scriptblock]
        $ReturnFilter={return $true}
    )
    process{
        Get-ChildItem $Directory -Directory|Where-Object $FolderFilter|Get-ChildItemAdvance -FolderFilter $FolderFilter -ReturnFilter $ReturnFilter
        Get-ChildItem $Directory|Where-Object $ReturnFilter
    }
}