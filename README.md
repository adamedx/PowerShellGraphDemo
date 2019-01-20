# Microsoft Graph via PowerShell Example

This repository demonstrates accessing the Microsoft Graph through PowerShell. The samples include scripts that obtain an access token for Microsoft Graph through the native (public) client authentication flow, make a call to the Graph, and deserialize the result.

The code here is a demonstration of the techniques required to use Microsoft Graph from PowerShell. A robust and feature-filled implementation of Graph via PowerShell can be found in the [AutoGraphPS](https://github.com/adamedx/autographps) project, which provides capabilities well beyond those in this demo repository.

## Installation

To install the samples, clone this repository on the system on which you'd like to execute the example scripts. You can clone with the following command:

```powershell
git clone https://github.com/adamedx/PowerShellGraphDemo
```

This will create a directory named `PowerShellGraphDemo` inside the current working directory. This new directory contains the contents of the repository.

## Usage

To exercise the two samples, you'll need to load them in PowerShell. From the root of the cloned repository directory, run the commands below -- the second is only needed if you want to learn about using [Microsoft Authentication Library (MSAL)](https://github.com/AzureAD/microsoft-authentication-library-for-dotnet) in PowerShell, though this is the recommended approach for obtaining Graph access tokens:

```powershell
. ./PowerShellGraphDemo.ps1 # For PowerShell script-only access to Graph
. ./Get-GraphAccessTokenFromMSAL.ps1 # Optional -- uses MSAL to obtain token, downloads MSAL from nuget.org in local directory the first time you run this
```

The first command contains code that shows the protocol down to the REST API level for OAuth2 and Microsoft Graph. The second command is only needed if you'd like to try MSAL. MSAL hides the OAuth2 protocol from the developer and thus eliminates the need for most of the code in [PowerShellGraphDemo.ps1](PowerShellGraphDemo.ps1) which is associated with obtaining the access token (arguably the most complex aspect of using Graph from a client application). Note that when you dot-source [Get-GraphAccessTokenFromMSAL.ps1](Get-GraphAccessTokenFromMSAL.ps1) above it will download MSAL from https://nuget.org and store it in a subdirectory of the directory that contains the script so that it can be used from a PowerShell function when you access Graph.

After you've run these once in a PowerShell session, you won't need to run them again.

Note that while the commands have default parameters that allow for simple execution in the examples below, they also take parameters so you can try out a wide range of Graph scenarios. Experiment with the parameters to obtain tokens with different permissions and access arbitrary parts of the graph.

### Sample 1: PowerShell-only example with explicit OAuth2 protocol

The functions below from [PowerShellGraphDemo.ps1](PowerShellGraphDemo.ps1) allow you to obtain an access token for Graph, and then use it to make a call to Graph:

* `GetGraphAccessToken`: Given an application id and scopes, this cmdlet displays a logon user interface and returns an authorization code `PSCustomObject` with the following fields:
  * `Token`: An access token that contains claims granting access to the MS Graph endpoint with the specified scopes as the user who signed in through the UX in the appropriate cloud (e.g. Public, Germany, China, US Government, etc.)
  * `GraphUri`: The URI for the MS Graph endpoint for which the token was acquired.
* `InvokeGraphRequest`: Invokes a REST method call against the specified MS Graph endpoint and relative URI with a particular HTTP verb and optional headers and HTTP request body and returns the resulting HTTP response

#### Example call to MS Graph
The following example should work against any cloud -- it will sign the user in and retrieve an access token for that user in their cloud and then make a call to MS Graph to get the `me` singleton that returns profile information about that user:

```powershell
$accessInfo = GetGraphAccessToken # This will present a logon page where you must sign in
$result = InvokeGraphRequest me -GraphBaseUri $accessInfo.GraphUri -GraphAccessToken $accessInfo.AccessToken
$result.content
```

The first line displays the login UX, and retrieves the accesss token and the MS Graph endpoint URI in which that token is valid and stores it in the variable `$accessInfo`. The second line invokes the `GET` verb on the URI `v1.0/me` relative to the previously obtained MS Graph URI using the token contained in `$accessInfo` and returns the response which in this case contains information such as the user's name, email address, etc. The returned result contains both the raw response and deserialized JSON Graph content, the last as Powershell objects. The third line emits those deserialized objects to the display for your inspection by accessing the `content` member of the result returned by `InvokeGraphRequest`.

By default, the URI accessed by `InvokeGraphRequest` would be `https://graph.microsoft.com/v1.0/me` which is an Azure Public cloud URI for Graph. `GetGraphAccessToken` allows the caller to override the logon endpoint and MS Graph endpoint so that clouds other than the Public cloud (e.g. the Germany cloud) may be used.

To see more details about the URI's accessed during authentication and Graph access, specify the `-verbose` option for either command.

### Sample 2: Get a token in PowerShell via MSAL

The next sample builds on the sample above but replaces `GetGraphAccessToken` with usage of [Microsoft Authentication Library (MSAL)](https://github.com/AzureAD/microsoft-authentication-library-for-dotnet) for .NET; this removes the need for the majority of the code in [PowerShellGraphDemo.ps1](PowerShellGraphDemo.ps1) which was involved in implementing the OAuth2 protocol and obtaining the token. All that's needed from [PowerShellGraphDemo.ps1](PowerShellGraphDemo.ps1) is the function `InvokeGraphRequest` which is really just a lightweight wrapper on top of PowerShell's built-in `Invoke-WebRequest` cmdlet.

MSAL is an actively developed and maintained project with support for authentication features well beyond what is demonstrated here and should be considered the preferred approach for PowerShell or any .NET-based platform to perform authentication. Remember: PowerShell can access any .NET code just as if it were built-in to PowerShell because PowerShell itself is built on .NET.

To call Graph in this way, use `Get-GraphAccessTokenFromMSAL` from the [Get-GraphAccessTokenFromMSAL.ps1](Get-GraphAccessTokenFromMSAL.ps1) script, and again `InvokeGraphRequest` from `PowerShellDemo.ps1`, both of which should be dot-sourced in your PowerShell session as described earlier:

```powershell
$accessToken = Get-GraphAccessTokenFromMSAL
$result = InvokeGraphRequest me -GraphAccessToken $accessToken
$result.content
```

Note that a key difference between the MSAL approach and the explicit OAuth2 example is that MSAL infers the Graph endpoint, https://graph.microsoft.com, from the permission scopes we supply (in the default case the sample specifies the scope `User.Read`). This is due to the fact that scopes like `User.Read` or `Directory.AccessAsUser.All` that are not specified as a URI are interpreted by the sample's default login endpoint https://login.microsoftonline.com/common/OAuth2 to mean an OAuth2 scope of `https://graph.microsoft.com/User.Read` and `https://graph.microsoft.com/Directory.AccessAsUser.all`. Thus one only needs to specify scopes as named in the Graph Permissions documentation in the call to MSAL's [PublicClientApplication class](https://docs.microsoft.com/en-us/dotnet/api/microsoft.identity.client.publicclientapplication?view=azure-dotnet)'s [AcquireTokenAsync](https://docs.microsoft.com/en-us/dotnet/api/microsoft.identity.client.publicclientapplication.acquiretokenasync?view=azure-dotnet) which takes in only `scopes` as a paremter to obtain a token for https://graph.microsoft.com. This is a special feature of the login endpoint to provide a simplified developer experience for Microsoft Graph.

Because the `InvokeGraphRequest` function here is not itself aware of this logic, we explicitly pass in the `GraphBaseUri` parameter -- for convenience it defaults to https://graph.microsoft.com, but if you were accessing Graph in a different cloud (e.g. https://graph.microsoft.de) you'd need to override it. For the pure PowerShell case, we implemented a more flexible `GetGraphAccessToken` function that could obtain tokens for arbitrary resources and not just Graph as a way of more generically demonstrating the OAuth2 protocol. So that function returned a structure indicating the resource for which the token was obtained, and was passed that along to `InokeGraphRequest` rather than hard-coding https://graph.microsoft.com as we did in this MSAL case.

## Assumptions and limitations

The samples here include the following limitations:

* They use the native client a.k.a. public client logon flow. This is suitable for running a PowerShell script from your workstation -- it cannot be used for web apps for instance.
* The sample `GetGraphAccessToken` obtains but does not return an ID token. If you modify the code in `GetGraphAccessToken` to surface the ID token, you must validate it, and the sample does not include this validation. For more details, see the [protocol documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-tokens#validating-tokens). Note that the ID token is not used by `InvokeGraphRequest` which consumes an access token.
* They require the ['Azure AD v2.0'](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-protocols) authorization protocols.
* Because of the above they require that the application be registered on the new application API `v2.0` [Azure AD Application Registration Portal](https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredAppsPreview). By default this sample uses a dedicated application id, but it can be overridden with your own registered v2.0 application on the portal.
* The use of MSAL in the `Get-GraphAccessTokenFromMSAL` function is just a small demonstration of what's possible with MSAL. MSAL makes it easy to use additional auth flows such as client credentials that allow for non-interactive access to MS Graph (e.g. for unattended automation in DevOps scenarios). Additionally MSAL supports capabilities to seamlessly cache and refresh tokens which normally last 60 minutes or less; this allows your application to avoid unnecessary round trips to the STS obtain another access token when making more than just one Graph call, and also avoids UX after the initial sign-in for interactive flows.


