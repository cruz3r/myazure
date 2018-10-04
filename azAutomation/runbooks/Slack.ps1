# Add to git test
<#
    .Author
	Trevor Sullivan <trevor@trevorsullivan.net>
	https://trevorsullivan.net
	https://twitter.com/pcgeek86
	
	.Description
	This Azure Automation Runbook serves as a template for bi-directionally integrating Microsoft Azure Automation
	with the Slack chat service, through the use of Webhooks for Slack and Azure Automation. You can build your own
	custom commands, similar to the ones that are defined towards the bottom of this Runbook. The Get-SlackParameter
	and Send-SlackMessage funcions are provided as helpful plumbing.
	
	NOTE: You need to configure a "custom slash command" for your Slack organization, as well as an "incoming webhook"
		  in order to take advantage of all of the features of this Azure Automation Runbook.
#>
param (
	[Object] $WebhookData
)

### Build a function that accepts Slack parameters 
function Get-SlackParameter {
	<#
	.Synopsis
	This function takes the input parameters to a Webhook call by the Slack service. The function translates the query
	string, provided by the Slack service, and returns a PowerShell HashTable of key-value pairs. Azure Automation accepts
	a $WebhookData input parameter, for Webhook invocations, and you should pass the value of the RequestBody property
	into this function's WebhookPayload parameter.
	
	.Parameter WebhookPayload
	This parameter accepts the Azure Automation-specific $WebhookData.RequestBody content, which contains
	input parameters from Slack. The function parses the query string, and returns a HashTable of key-value
	pairs, that represents the input parameters from a Webhook invocation from Slack.
	
	eg. var1=value1&var2=value2&var3=value3 
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string] $WebhookPayload
	)
	
	$ParamHT = @{ };
	$Params = $WebhookPayload.Split('&');
	
	foreach ($Param in $Params) {
		try {
			$Param = $Param.Split('=');
			$ParamHT.Add($Param[0], [System.Net.WebUtility]::UrlDecode($Param[1]))			
		}
		catch {
			Write-Warning -Message ('Possible null parameter value for {0}' -f $Param[0]);
		}
	}
	
	Write-Output -InputObject $ParamHT;
}

### Invoke the retrieval of Slack parameters

### Example result:
<#
Name                           Value                                                                                    
----                           -----                                                                                    
team_id                        S1L63JMUI                                                                                
user_name                      trevor                                                                                   
channel_id                     BOU20EN7T                                                                                
response_url                   https://hooks.slack.com/commands/S1L63JMUI/22387674759/Cw62aJBtn2E29IBkS1ZkFqiP          
command                        /runbook                                                                                 
text                           list                                                                                         
user_id                        U0L26M71V                                                                                
team_domain                    artofshell
token                          baMLUbHjU32psaPGvQm2sF4j                                                                 
channel_name                   general
#>
$SlackParams = Get-SlackParameter -WebhookPayload $WebhookData.RequestBody;

### For testing, output the list of Slack parameters. Normally not needed for production Runbooks.
#Write-Output -InputObject $SlackParams;
Write-Verbose -Message $SlackParams;

function Send-SlackMessage {
	<#
	.Synopsis
	This function sends a message to a Slack channel.
	
	.Description
	This function sens a message to a Slack channel. There are several parameters that enable you to customize
	the message that is sent to the channel. For example, you can target the message to a different channel than
	the Slack incoming webhook's default channel. You can also target a specific user with a message. You can also
	customize the emoji and the username that the message comes from.
	
	For more information about incoming webhooks in Slack, check out this URL: https://api.slack.com/incoming-webhooks
	
	.Parameter Message
	The -Message parameter specifies the text of the message that will be sent to the Slack channel.
	
	.Parameter Channel
	The name of the Slack channel that the message should be sent to.
	
	- You can specify a channel, using the syntax: #<channelName>
	- You can target the message at a specific user, using the syntax: @<username>
	
	.Parameter $Emoji
	The emoji that should be displayed for the Slack message. There is an emoji cheat sheet available here:
	http://www.emoji-cheat-sheet.com/
	
	.Parameter Username
	The username that the Slack message will come from. You can customize this with any string value.
	
	.Links
	https://api.slack.com/incoming-webhooks - More information about Slack incoming webhooks
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string] $Message
	  , [Parameter(Mandatory = $false)]
	    [string] $Channel = ''
	  , [Parameter(Mandatory = $false)]
	    [string] $Emoji = ''
	  , [Parameter(Mandatory = $false)]
	    [string] $Username = 'Azure Automation'
	)
	
	### Build the payload for the REST method call
	$RestBody = @{ 
		text = $Message;
		username = $Username;
		icon_emoji = $Emoji;
		}
	
	### Build the command invocation parameters for Splatting on Invoke-RestMethod
	$RestCall = @{
		Body = (ConvertTo-Json -InputObject $RestBody);
		Uri = Get-AutomationVariable -Name SlackIncomingWebhook;
		ContentType = 'application/json';
		Method = 'POST';		
	}
	
	### Invoke the REST method call to the Slack service's webhook.
	Invoke-RestMethod @RestCall;
	
	Write-Verbose -Message 'Sent message to Slack service';
}

<####
NOTE:
	The input parameters from Slack were parsed in the earlier call to the Get-SlackParameter function.
	You can re-use the Send-SlackMessage function to send messages to your Slack channel.
	YOUR MAIN LOGIC GOES DOWN HERE.
####>


### This example posts a Slack message with the list of Azure Resource Manager (ARM) Resource Groups
###
### NOTE: This specific example is dependent on a Credential Asset named "AzureAdmin" that has access to your
###       Microsoft Azure subscription. You can safely delete this example, and replace it with your own, that
###       integrates with a different external system.
if ($SlackParams.Text -eq 'listarmgroups') {
	Write-Verbose -Message 'Listing Microsoft Azure Resource Manager (ARM) Resource Groups';
	$null = Add-AzureRmAccount -Credential (Get-AutomationPSCredential -Name AzureAdmin) -SubscriptionName "Visual Studio Premium with MSDN";
	Send-SlackMessage -Message ((Get-AzureRmResourceGroup).ResourceGroupName -join "`n");
	return;
}

### This example deletes an Azure Resource Manager (ARM) Resource Group, based on the name specified by the user.
### After the Resource Group has been deleted, a Slack message is sent as confirmation.
###
###   Example Invocation (from Slack): 
###     /runbook delarmgroup ArtofShell-Network
if ($SlackParams.Text -like 'delarmgroup*') {
	try {
		$ResourceGroupName = $SlackParams.Text.Split(' ')[1];
		$null = Add-AzureRmAccount -Credential (Get-AutomationPSCredential -Name AzureAdmin) -SubscriptionName "Visual Studio Premium with MSDN";
		Write-Verbose -Message ('Deleting ARM Resource Group named {0}' -f $ResourceGroupName);
		Remove-AzureRmResourceGroup -Name $ResourceGroupName -Force -ErrorAction Stop;
		Send-SlackMessage -Message ('Azure Automation successfully deleted the ARM Resource Group named {0}' -f $ResourceGroupName)
	}
	catch {
		throw ('Error occurred while deleting ARM Resource Group {0}: {1}' -f $ResourceGroupName, $PSItem.Exception.Message);
	}
	return;
}

### This example creates an Azure Resource Manager (ARM) Resource Group, based on the name and location specified by the user.
### After the Resource Group has been created, a Slack message is sent as confirmation.
###
###   Example Invocation (from Slack): 
###     /runbook newarmgroup CloudAcademyRG WestEurope
if ($SlackParams.Text -like 'newarmgroup*') {
	try {
		$SlackTextArr = $SlackParams.Text.Split(' ');
		$ResourceGroup = @{
			Name = $SlackTextArr[1];
			Location = $SlackTextArr[2];
			Force = $true;	
		}
		
		$null = Add-AzureRmAccount -Credential (Get-AutomationPSCredential -Name AzureAdmin) -SubscriptionName "Visual Studio Premium with MSDN";
		Write-Verbose -Message ('Creating ARM Resource Group named {0} in the {1} region.' -f $ResourceGroup.Name, $ResourceGroup.Location);
		New-AzureRmResourceGroup @ResourceGroup -ErrorAction Stop;
		Send-SlackMessage -Message ('Azure Automation successfully create the ARM Resource Group named {0} in region {1}' -f $ResourceGroup.Name, $ResourceGroup.Location)
	}
	catch {
		throw ('Error occurred while creating ARM Resource Group {0}: {1}' -f $ResourceGroup.Name, $PSItem.Exception.Message);
	}
	return;
}

### This is a catch-all. If the Runbook command isn't found, then an error will be sent to the Slack channel
Try{
$UserName = $SlackParams.user_name
$UserID = $SlackParams.user_id
Send-SlackMessage -Message ($UserName)
}catch{
	$matches
	"Failed to say hello"
}

Send-SlackMessage -Message ('No Slack command found in Azure Automation Runbook: {0}' -f $SlackParams.Text.Split(' ')[0]);
