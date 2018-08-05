# Microsoft Graph via PowerShell Example

This repository demonstrates accessing the Microsoft Graph through PowerShell. It includes obtaining the access token for Microsoft Graph through the native (public) client authentication flow, making a call to the Graph, and deserializing the result.

The code here is a demonstration of the techniques required to use Microsoft Graph from PowerShell. A robust and feature-filled implementation of Graph via PowerShell can be found in the [PoshGraph](https://github.com/adamedx/poshgraph) project, which goes well beyond this demo repository.

## Installation

To install the example, clone this repository on the system on whic you'd like to execute the example script. You can clone with the following command:

```powershell
git clone https://github.com/adamedx/PowerShellGraphDemo
```

This will create a directory named `PowerShellGraphDemo` inside the current working directory. This new directory contains the contents of the repository.

## Usage

To use the sample, you'll need to load it in PowerShell. From the root of the cloned repository directory, run the command below

```powershell
. .\PowerShellGraphDemo.ps1` to load the sample cmdlets.
```

After you've run this once in a PowerShell session, you won't need to run it again, you can use the following two commands from the sample:

* `GetGraphAccessToken`: Given an application id and scopes, this cmdlet displays a logon user interface and returns an authorization code `PSCustomObject` with the following fields:
  * `Token`: An access token that contains claims granting access to the MS Graph endpoint with the specified scopes as the user who signed in through the UX in the appropriate cloud (e.g. Public, Germany, China, US Government, etc.)
  * `GraphUri`: The URI for the MS Graph endpoint for which the token was acquired.
* InvokeGraphRequest`: Invokes a REST method call against the specified MS Graph endpoint and relative URI with a particular HTTP verb and optional headers and HTTP request body and returns the resulting HTTP response

### Example call to MS Graph
The following example should work against any cloud -- it will sign the user in and retrieve an access token for that user in their cloud and then make a call to MS Graph to get the `me` singleton that returns profile information about that user:

```powershell
$accessInfo = GetGraphAccessToken
$result = InvokeGraphRequest $accessInfo.GraphUri v1.0/me $accessInfo.token
$result.content
```

The first line displays the login UX, and retrieves the subsequent accesss token and the MS Graph endpoint URI in which that token is valid. The second line invokes the `GET` verb on the URI `v1.0/me` relative to the previously obtained MS Graph URI using the token and returns the response which in this case contains information such as the user's name, email address, etc. The returned result contains both the raw response and deserialized JSON Graph content as Powershell objects. The third line emits those deserialized objects by accessing the `content` member of the result returned by `InvokeGraphRequest`.

By default, the URI accessed by `InvokeGraphRequest` would be `https://graph.microsoft.com/v1.0/me`. `GetGraphAccessToken` allows the caller to override the logon endpoint and MS Graph endpoint so that clouds other than the Public cloud (e.g. the Germany cloud) may be used.

To see more details about the URI's access during authentication and Graph access, specify the `-verbose` option for either command.

## Assumptions and limitations of the sample

This sample has the following limitations:

* It uses the native client a.k.a. public client logon flow. This is suitable for running a PowerShell script from your workstation -- it cannot be used for web apps for instance.
* The sample `GetGraphAccessToken` returns an ID token -- you must validate the ID token if you use it, and the sample does not include this validation. For more details, see the [protocol documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-tokens#validating-tokens). Note that the ID token is not used by `InvokeGraphRequest` which consumes an access token.
* It requires the `v2.0` authorization protocols.
* Because of the above it requires that the application be registered on the `v2.0` [application portal](https://apps.dev.microsoft.com). By default this sample uses a dedicated application id, but it can be overridden with your own registered v2.0 application on the portal.
* A more full-featured replacement for `GetGraphAccessToken` is the [Microsoft Authentication Library (MSAL)](https://github.com/AzureAD/microsoft-authentication-library-for-dotnet). It is a .NET-based library, so it can be used from PowerShell and will evolve with the latest authentication protocol changes. `GetGraphAccessToken` provides an educaitonal look at the protocols and gives an idea of what libraries like MSAL provide; ultimately MSAL is a much better choice for production use cases.


