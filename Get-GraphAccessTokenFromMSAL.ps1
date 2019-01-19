# Copyright 2019, Adam Edwards
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

# 0 - Install the MSAL assembly in a subdirectory if it's not already there -- as long as it's not
# deleted, this is a no-op -- the assembly stay here across PowerShell sessions, reboots, etc.
# The installation is really just a package download from nuget.org and an unzip into the subdirectory 'lib'.
if ( ! (gi $psscriptroot/lib/Microsoft.Identity.Client.* -erroraction ignore) ) {
    install-package -Source nuget.org -ProviderName nuget -SkipDependencies Microsoft.Identity.Client -Destination $psscriptroot/lib -force -forcebootstrap | out-null
}

# 1 - Load the MSAL assembly -- needed once per PowerShell session
[System.Reflection.Assembly]::LoadFrom((gi $psscriptroot/lib/Microsoft.Identity.Client.*/lib/net45/Microsoft.Identity.Client.dll).fullname) | out-null

function Get-GraphAccessTokenFromMSAL {
    [cmdletbinding()]
    param($appId = '53316905-a6e5-46ed-b0c9-524a2379579e', $redirectUri = 'urn:ietf:wg:oauth:2.0:oob', $graphScopes = 'user.read', $logonEndpoint = 'https://login.microsoftonline.com/common/oauth2/v2.0' )

    # 2 - Get the MSAL public client auth context object
    $authContext = [Microsoft.Identity.Client.PublicClientApplication]::new($appId, $logonEndpoint, $null)

    # 3a - Invoke the AcquireTokenTokenAsync method
    $asyncResult = $authContext.AcquireTokenAsync([System.Collections.Generic.List[string]] $graphScopes)

    # 3b Wait for the method to complete
    $token = $asyncResult.Result

    if ( $asyncResult.Status -eq 'Faulted' ) {
        write-error $asyncResult.Exception
    } else {
        $token
    }
}
