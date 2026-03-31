@{
    # Write-Host is intentional in CLI install/uninstall scripts for user-facing output.
    Rules = @('PSUseDeclaredVarsMoreThanAssignments')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseBOMForUnicodeEncodedFile'
    )
}
