# ingress-gatekeeper

Monitors instances running in cloud accounts and whitelists them on Kubernetes nginx ingress objects

## Usage

Environment variables to pass:

`GCP_PROJECT_IDS`

Space separated list of Google cloud project ids to scan for IPs.

`INGRESS_NAMES`

Space separated list of ingress names in the same namespace to be managed.

`STATIC_IP_RANGES`

Space separated list of IP CIDR ranges to white list (optional).

```
STATIC_IP_RANGES="192.168.1.0/24 192.168.5.0/24"
GCP_PROJECT_IDS="test-project prod-project"
INGRESS_NAMES="test-ingress"
```

### Credentials

A secret named test-ingress needs to be created in the same namespace, containing the key `auth.json`, which value is the base64 encoded json formatted private key from a Google account with enough permissions to list instances. This secret should be mounted at the path `/creds` in the container.

## Testing

use [basht](https://github.com/progrium/basht)

---

Copyright © 2018 Ocado

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
