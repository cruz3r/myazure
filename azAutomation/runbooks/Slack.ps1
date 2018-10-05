if ($SlackParams.Text -eq 'testuser') {

    try{
        $null = Add-AzureRmAccount -Credential (Get-AutomationPSCredential -Name AzureAdmin) -SubscriptionName "Visual Studio Premium with MSDN";
        $UserName = $SlackParams.user_name

        $UserID = $SlackParams.user_id
        $secGroup = Get-AutomationVariable -Name AZAutomation
        write-verbose $secGroup
        # write-output $secGroup
        $SlackToken = Get-AutomationVariable -Name SlackToken

        $url = ("https://slack.com/api/users.info?token=$SlackToken&user=$UserID&pretty=1")

        $email = (((invoke-webrequest $url -UseBasicParsing).content | ConvertFrom-Json).user.profile | Select-Object -ExpandProperty email)
        write-output $email
        write-output (Get-AzureRmADGroupMember -GroupObjectId $secGroup)
        # This is looking for guest users in AzureAD if the Email has _ or # it will not work
        $accounts = (Get-AzureRmADGroupMember -GroupObjectId $secGroup).userPrincipalName | ForEach-Object { if ($_ -match "#"){($_ -split "#")[0] -replace "_","@" }else{$_}}
        Write-Output $accounts
        if ($accounts -contains $email){
            "YAY Continue"
            Send-SlackMessage -Message ($UserName)
            Send-SlackMessage -Message ($email)
        }else{
            Send-SlackMessage -Message "Your not in the group"
            "Your not in the group"
            write-output $accounts
        }

    }
    catch{
        $err = $Error[0].Exception.message
        write-output $err
        "Failed to say hello"
        Send-SlackMessage -Message $err
    }

    return;
}
