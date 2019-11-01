# ingress-gatekeeper

Monitors instances running in gcp cloud accounts and manages istio whitelist handler objects in Kubernetes, merging optional existing whitelists and GCP cloud instance ips.

## Usage

Environment variables to pass:

`GCP_PROJECT_IDS`

Space separated list of Google cloud project ids to scan for IPs. (Optional)

`SOURCE_HANDLER_NAMES`

Space separated list of istio handler objects in the same namespace to be merged or used as a base list of static ips. (Optional)

`DEST_HANDLER_NAME`

Output istio handler object to be created/managed. This can then be used in your istio rule.

```
SOURCE_HANDLER_NAMES="headoffice-ips remoteoffice-ips"
GCP_PROJECT_IDS="test-project prod-project"
DEST_HANDLER_NAME="test-ingress"
```

### Credentials

For listing GCP instances, a secret needs to be created in the same namespace, containing the key `auth.json`, which value is the base64 encoded json formatted private key from a Google account with enough permissions to list instances. This secret should be mounted at the path `/creds` in the container.

## Testing

use [basht](https://github.com/progrium/basht)

## Older versions

Note that ingress-gatekeeper version 1.x handled nginx ingress whitelisting

Versions below 2.2 used listcheckers instead of handlers.

---

Copyright © 2018-2019 Ocado

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
