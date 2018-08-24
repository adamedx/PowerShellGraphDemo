# Copyright 2018, Adam Edwards
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set-strictmode -version 2

function GetScopeParameter($resourceUri, $graphScopes, $encode = $false) {
    $space = if ( $encode ) {
        '%20'
    } else {
        ' '
    }

    # The openid scope is required -- it enables sign-in
    # The offline_access scope is optional -- it enables the
    # return of a refresh token
    $defaultScopes = 'openid', 'offline_access'

    $scopeParameter = $defaultScopes -join $space

    if ( $graphScopes ) {
        $graphScopes | foreach {
            if ( $scopeParameter.length -gt 0 ) {
                $scopeParameter += $space
            }
            $value = if ( $encode ) {
                [System.Net.WebUtility]::UrlEncode("$resourceUri/$_")
            } else {
                "$resourceUri/$_"
            }
            $scopeParameter += $value
        }
    }
    $scopeParameter
}

function GetNonce {
    $random = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()

    $bytes = [System.Byte[]]::CreateInstance([System.Byte], 32)

    try {
        $random.GetNonZeroBytes($bytes)
    } catch {
        throw
    } finally {
        $random.Dispose()
    }

    [Convert]::ToBase64String($bytes)
}

function GetAuthCodeUri($appId, $redirectUri, $resourceUri, $graphScopes, $logonEndpoint) {
    add-type -AssemblyName System.Windows.Forms

    $loginUri = $logonEndpoint.trimend('/'), 'authorize' -join '/'

    $clientIdEscaped = [System.Net.WebUtility]::UrlEncode($appId)
    $responseType = 'code'
    $redirectUriEscaped = [System.Net.WebUtility]::UrlEncode($redirectUri)
    $responseMode = 'fragment'
    $state = [System.Net.WebUtility]::UrlEncode((new-guid | select -expandproperty guid))
    $nonce = GetNonce
    $scopesEscaped = GetScopeParameter $resourceUri $graphScopes $true

    $queryTemplate='client_id={0}&response_type={1}&redirect_uri={2}&response_mode={3}&scope={4}&state={5}&nonce={6}&prompt=login'
    $queryString = $queryTemplate -f $clientIdEscaped, $responseType, $redirectUriEscaped, $responseMode, $scopesEscaped, $state, $nonce

    @{
        Uri = [Uri] ($loginUri, $queryString -join '?')
        RequestedState = $state
    }
}

function GetTokenRequestBody($appId, $redirectUri, $resourceUri, $graphScopes, $authCode) {
    $scopes = GetScopeParameter $resourceUri $graphScopes $false

    @{
        client_id = $appId
        scope = $scopes
        grant_type = 'authorization_code'
        code = $authCode
        redirect_uri = $redirectUri
    }
}

function GetTokenUri($logonEndpoint) {
    $tokenUri = $logonEndpoint.trimend('/'), 'token' -join '/'
    [Uri] $tokenUri
}

function GetAuthCodeInfo($authUri) {
    add-type -AssemblyName System.Windows.Forms

    $form = new-object -typename System.Windows.Forms.Form -property @{width=480;height=640}
    $browser = new-object -typeName System.Windows.Forms.WebBrowser -property @{width=440;height=640;url=$authUri }

    $resultUri = $null
    $authError = $null
    $completedBlock = {
        # Use set-variable to access a variable outside the scope of this block
        set-variable resultUri -scope 1 -value $browser.Url
        if ($resultUri -match "error=[^&]*|code=[^&]*") {
            $authError = $resultUri
            $form.Close()
        }
    }

    $browser.Add_DocumentCompleted($completedBlock)
    $browser.ScriptErrorsSuppressed = $true

    $form.Controls.Add($browser)
    $form.Add_Shown({$form.Activate()})
    $form.ShowDialog() | out-null

    # We used 'fragment' for the response type, so strip off
    # the leading '#' character
    $decodedUri = ([System.Net.WebUtility]::UrlDecode($resultUri.fragment) -split '#')[1]

    $queryResponseParameters = @{}

    ($decodedUri -split '&') | foreach {
        $pair = $_ -split '='

        $key = $pair[0]
        $value = $pair[1]

        $queryResponseParameters[$key] = $value
    }


    $errorDescription = if ( $queryResponseParameters['error'] ) {
        $authError = $queryResponseParameters['error']
        $queryResponseParameters['error_description']
    }

    if ( $authError ) {
        write-error ("Auth error: {0}: '{2}' - {1}" -f $authError, $errorDescription, $resultUri)
    }

    @{
        ResponseUri = $resultUri
        ResponseParameters = $queryResponseParameters
    }
}

function GetGraphAccessToken {
    [cmdletbinding()]
    param($appId = '53316905-a6e5-46ed-b0c9-524a2379579e', $redirectUri = 'https://login.microsoftonline.com/common/oauth2/nativeclient', $graphScopes = 'user.read', $graphUri = 'https://graph.microsoft.com', $logonEndpoint = 'https://login.microsoftonline.com/common/oauth2/v2.0' )

    $erroractionpreference = 'stop'

    $authCodeUri = GetAuthCodeUri $appId $redirectUri $graphUri $graphScopes $logonEndpoint
    $authCodeInfo = GetAuthCodeInfo $authCodeUri.Uri

    if ( $authCodeUri.RequestedState -ne $authCodeInfo.ResponseParameters.State ) {
        write-error ("State value '{0}' was specified in the auth code request, but the response returned a different state value of '{1}'" -f $authCodeUri.RequestedState, $authCodeInfo.State)
    } else {
        write-verbose ("Requested state value '{0}' matches the state value '{1}' returned in the response parameters; the response is valid." -f $authCodeUri.RequestedState, $authCodeInfo.ResponseParameters.State)
    }

    if ( $verbosepreference -ne 'silentlycontinue' ) {
        write-verbose 'Successfully retrieved authorization information'
        write-verbose 'Authorization response parameters:'
        $authCodeInfo.responseparameters.keys | foreach {
            write-verbose "`t$($_): $($authCodeInfo.responseparameters[$_])"
        }
    }

    $tokenUri = GetTokenUri $logonEndpoint

    $tokenRequestBody = GetTokenRequestBody $appId $redirectUri $graphUri $graphScopes $authCodeInfo.ResponseParameters.Code
    $tokenResponse = invoke-webrequest -method POST -usebasicparsing -uri $tokenUri -body $tokenRequestBody -headers @{'Content-Type'='application/x-www-form-urlencoded'} -erroraction stop

    write-verbose "Token: $($tokenResponse.content)"

    [PSCustomObject] @{
        GraphUri = $graphUri
        Token = $tokenResponse.content | convertfrom-json
    }
}

function InvokeGraphRequest {
    [cmdletbinding()]
    param( $graphBaseUri, $graphRelativeUri, $graphAccessToken, $graphMethod = 'GET', $body, $headers )

    $erroractionpreference = 'stop'

    $graphUri = $graphBaseUri.trimend('/'), $graphRelativeUri -join '/'

    $requestHeaders = @{
        'Content-Type' = 'application/json'
        Authorization  = $graphAccessToken.access_token
    }

    if ( $headers ) {
        $headers.keys | foreach {
            $requestHeaders[$_] = $headers[$_]
        }
    }

    $bodyArgument = @{}

    if ( $body ) {
        $bodyArgument['body'] = $body
    }

    $userAgent = 'PowerShellGraphDemo/0.1 (Windows NT; Windows NT 10.0; en-US)'

    $result = invoke-webrequest -usebasicparsing -method $graphMethod -uri $graphUri -headers $requestHeaders @bodyArgument -useragent $userAgent -erroraction stop

    $deserializedContent = $result.content | convertfrom-json -erroraction silentlycontinue

    [PSCustomObject] @{
        Content = $deserializedContent
        RawResult = $result
    }
}

# Here is an example usage below:
# $accessInfo = GetGraphAccessToken # -verbose # This will get you an access token and the location of a Graph endpoint
# $result = InvokeGraphRequest $accessInfo.GraphUri v1.0/me $accessInfo.token # -verbose # This makes a Graph call on that endpoint with the access token
# $result.content # Conveniently access the JSON content as deserialized PowerShell objects

