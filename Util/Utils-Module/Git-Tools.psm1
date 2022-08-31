function Get-RepoName{
    process{
        $gitRepoName=($gitUrl.replace(".git","") -split "/")[-1]
        Write-Host "Current git repo name is $gitRepoName"
        return $gitRepoName
    }
}
function Get-RepoHost{
    process{

    }
}