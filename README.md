# Manage Windows NLB Cluster VSTS task
A small task to manage a Windows NLB cluster.

## Requirements
- [tfx-cli](https://github.com/Microsoft/tfs-cli)
- [Pester](https://github.com/pester/Pester)
- Powershell v3.0 or higher

## Testing

To run unit tests execute the following powershell command at the test directory:

``` powershell
Invoke-Pester -Script .\tests\ManageNlbCluster.Tests.ps1 -CodeCoverage .\ManageNlbCluster.ps1
```

## Build and Publish

To upload the task to an VSTS account, use the tfx-cli.

### Login
```
tfx login --service-url https://youraccount.visualstudio.com/DefaultCollection
```
Enter your Personal Access Token.

### Upload task

At the root of repository execute the following command:

```
tfx build tasks upload --task-path src
```

# Contributing

Issues and pull-requests are welcome.
