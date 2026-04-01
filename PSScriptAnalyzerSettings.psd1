@{
    # Write-Host is intentional in CLI install/uninstall scripts for user-facing output.
    # PSUseBOMForUnicodeEncodedFile: UTF-8 without BOM works fine with PowerShell 5.1+.
    # PSReviewUnusedParameter: $Voice is used inside Select-Voice via script scope.
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseBOMForUnicodeEncodedFile',
        'PSReviewUnusedParameter'
    )
}
