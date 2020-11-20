#!/bin/bash

# Copyright 2019 - 2020 Crunchy Data Solutions, Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##########
# SETUP #
#########

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# PGO_CMD should either be "kubectl" or "oc" -- defaulting to kubectl
PGO_CMD=${PGO_CMD:-kubectl}

# A namespace that exists in NAMESPACE env var - see examples/envs.sh
export NS=pgouser1

###########
# CLEANUP #
##########

# remove any existing resources from a previous run
$PGO_CMD delete secret -n $NS \
	fromcrd-postgres-secret \
	fromcrd-primaryuser-secret \
	fromcrd-testuser-secret \
	fromcrd-backrest-repo-config > /dev/null
$PGO_CMD delete pgcluster fromcrd -n $NS
$PGO_CMD delete pvc fromcrd fromcrd-pgbr-repo  -n $NS
# remove the public/private keypair from the previous run
rm $DIR/fromcrd-key $DIR/fromcrd-key.pub

###############
# EXAMPLE RUN #
###############

# generate a SSH public/private keypair for use by pgBackRest
ssh-keygen -t ed25519 -N '' -f $DIR/fromcrd-key

# base64 encoded the keys for the generation of the Kube secret, and place
# them into variables temporarily
PUBLIC_KEY_TEMP=$(cat $DIR/fromcrd-key.pub | base64)
PRIVATE_KEY_TEMP=$(cat $DIR/fromcrd-key | base64)

export PUBLIC_KEY="${PUBLIC_KEY_TEMP//[$'\n']}"
export PRIVATE_KEY="${PRIVATE_KEY_TEMP//[$'\n']}"

unset PUBLIC_KEY_TEMP
unset PRIVATE_KEY_TEMP

# create the backrest-repo-config example file and substitute in the newly
# created keys
cat <<-EOF > $DIR/backrest-repo-config.yaml
apiVersion: v1
data:
  authorized_keys: ${PUBLIC_KEY}
  id_ed25519: ${PRIVATE_KEY}
  ssh_host_ed25519_key: ${PRIVATE_KEY}
  config: SG9zdCAqClN0cmljdEhvc3RLZXlDaGVja2luZyBubwpJZGVudGl0eUZpbGUgL3RtcC9pZF9lZDI1NTE5ClBvcnQgMjAyMgpVc2VyIHBnYmFja3Jlc3QK
  sshd_config: IwkkT3BlbkJTRDogc3NoZF9jb25maWcsdiAxLjEwMCAyMDE2LzA4LzE1IDEyOjMyOjA0IG5hZGR5IEV4cCAkCgojIFRoaXMgaXMgdGhlIHNzaGQgc2VydmVyIHN5c3RlbS13aWRlIGNvbmZpZ3VyYXRpb24gZmlsZS4gIFNlZQojIHNzaGRfY29uZmlnKDUpIGZvciBtb3JlIGluZm9ybWF0aW9uLgoKIyBUaGlzIHNzaGQgd2FzIGNvbXBpbGVkIHdpdGggUEFUSD0vdXNyL2xvY2FsL2JpbjovdXNyL2JpbgoKIyBUaGUgc3RyYXRlZ3kgdXNlZCBmb3Igb3B0aW9ucyBpbiB0aGUgZGVmYXVsdCBzc2hkX2NvbmZpZyBzaGlwcGVkIHdpdGgKIyBPcGVuU1NIIGlzIHRvIHNwZWNpZnkgb3B0aW9ucyB3aXRoIHRoZWlyIGRlZmF1bHQgdmFsdWUgd2hlcmUKIyBwb3NzaWJsZSwgYnV0IGxlYXZlIHRoZW0gY29tbWVudGVkLiAgVW5jb21tZW50ZWQgb3B0aW9ucyBvdmVycmlkZSB0aGUKIyBkZWZhdWx0IHZhbHVlLgoKIyBJZiB5b3Ugd2FudCB0byBjaGFuZ2UgdGhlIHBvcnQgb24gYSBTRUxpbnV4IHN5c3RlbSwgeW91IGhhdmUgdG8gdGVsbAojIFNFTGludXggYWJvdXQgdGhpcyBjaGFuZ2UuCiMgc2VtYW5hZ2UgcG9ydCAtYSAtdCBzc2hfcG9ydF90IC1wIHRjcCAjUE9SVE5VTUJFUgojClBvcnQgMjAyMgojQWRkcmVzc0ZhbWlseSBhbnkKI0xpc3RlbkFkZHJlc3MgMC4wLjAuMAojTGlzdGVuQWRkcmVzcyA6OgoKSG9zdEtleSAvc3NoZC9zc2hfaG9zdF9lZDI1NTE5X2tleQoKIyBDaXBoZXJzIGFuZCBrZXlpbmcKI1Jla2V5TGltaXQgZGVmYXVsdCBub25lCgojIExvZ2dpbmcKI1N5c2xvZ0ZhY2lsaXR5IEFVVEgKU3lzbG9nRmFjaWxpdHkgQVVUSFBSSVYKI0xvZ0xldmVsIElORk8KCiMgQXV0aGVudGljYXRpb246CgojTG9naW5HcmFjZVRpbWUgMm0KUGVybWl0Um9vdExvZ2luIG5vClN0cmljdE1vZGVzIG5vCiNNYXhBdXRoVHJpZXMgNgojTWF4U2Vzc2lvbnMgMTAKClB1YmtleUF1dGhlbnRpY2F0aW9uIHllcwoKIyBUaGUgZGVmYXVsdCBpcyB0byBjaGVjayBib3RoIC5zc2gvYXV0aG9yaXplZF9rZXlzIGFuZCAuc3NoL2F1dGhvcml6ZWRfa2V5czIKIyBidXQgdGhpcyBpcyBvdmVycmlkZGVuIHNvIGluc3RhbGxhdGlvbnMgd2lsbCBvbmx5IGNoZWNrIC5zc2gvYXV0aG9yaXplZF9rZXlzCkF1dGhvcml6ZWRLZXlzRmlsZQkvc3NoZC9hdXRob3JpemVkX2tleXMKCiNBdXRob3JpemVkUHJpbmNpcGFsc0ZpbGUgbm9uZQoKI0F1dGhvcml6ZWRLZXlzQ29tbWFuZCBub25lCiNBdXRob3JpemVkS2V5c0NvbW1hbmRVc2VyIG5vYm9keQoKIyBGb3IgdGhpcyB0byB3b3JrIHlvdSB3aWxsIGFsc28gbmVlZCBob3N0IGtleXMgaW4gL2V0Yy9zc2gvc3NoX2tub3duX2hvc3RzCiNIb3N0YmFzZWRBdXRoZW50aWNhdGlvbiBubwojIENoYW5nZSB0byB5ZXMgaWYgeW91IGRvbid0IHRydXN0IH4vLnNzaC9rbm93bl9ob3N0cyBmb3IKIyBIb3N0YmFzZWRBdXRoZW50aWNhdGlvbgojSWdub3JlVXNlcktub3duSG9zdHMgbm8KIyBEb24ndCByZWFkIHRoZSB1c2VyJ3Mgfi8ucmhvc3RzIGFuZCB+Ly5zaG9zdHMgZmlsZXMKI0lnbm9yZVJob3N0cyB5ZXMKCiMgVG8gZGlzYWJsZSB0dW5uZWxlZCBjbGVhciB0ZXh0IHBhc3N3b3JkcywgY2hhbmdlIHRvIG5vIGhlcmUhCiNQYXNzd29yZEF1dGhlbnRpY2F0aW9uIHllcwojUGVybWl0RW1wdHlQYXNzd29yZHMgbm8KUGFzc3dvcmRBdXRoZW50aWNhdGlvbiBubwoKIyBDaGFuZ2UgdG8gbm8gdG8gZGlzYWJsZSBzL2tleSBwYXNzd29yZHMKQ2hhbGxlbmdlUmVzcG9uc2VBdXRoZW50aWNhdGlvbiB5ZXMKI0NoYWxsZW5nZVJlc3BvbnNlQXV0aGVudGljYXRpb24gbm8KCiMgS2VyYmVyb3Mgb3B0aW9ucwojS2VyYmVyb3NBdXRoZW50aWNhdGlvbiBubwojS2VyYmVyb3NPckxvY2FsUGFzc3dkIHllcwojS2VyYmVyb3NUaWNrZXRDbGVhbnVwIHllcwojS2VyYmVyb3NHZXRBRlNUb2tlbiBubwojS2VyYmVyb3NVc2VLdXNlcm9rIHllcwoKIyBHU1NBUEkgb3B0aW9ucwojR1NTQVBJQXV0aGVudGljYXRpb24geWVzCiNHU1NBUElDbGVhbnVwQ3JlZGVudGlhbHMgbm8KI0dTU0FQSVN0cmljdEFjY2VwdG9yQ2hlY2sgeWVzCiNHU1NBUElLZXlFeGNoYW5nZSBubwojR1NTQVBJRW5hYmxlazV1c2VycyBubwoKIyBTZXQgdGhpcyB0byAneWVzJyB0byBlbmFibGUgUEFNIGF1dGhlbnRpY2F0aW9uLCBhY2NvdW50IHByb2Nlc3NpbmcsCiMgYW5kIHNlc3Npb24gcHJvY2Vzc2luZy4gSWYgdGhpcyBpcyBlbmFibGVkLCBQQU0gYXV0aGVudGljYXRpb24gd2lsbAojIGJlIGFsbG93ZWQgdGhyb3VnaCB0aGUgQ2hhbGxlbmdlUmVzcG9uc2VBdXRoZW50aWNhdGlvbiBhbmQKIyBQYXNzd29yZEF1dGhlbnRpY2F0aW9uLiAgRGVwZW5kaW5nIG9uIHlvdXIgUEFNIGNvbmZpZ3VyYXRpb24sCiMgUEFNIGF1dGhlbnRpY2F0aW9uIHZpYSBDaGFsbGVuZ2VSZXNwb25zZUF1dGhlbnRpY2F0aW9uIG1heSBieXBhc3MKIyB0aGUgc2V0dGluZyBvZiAiUGVybWl0Um9vdExvZ2luIHdpdGhvdXQtcGFzc3dvcmQiLgojIElmIHlvdSBqdXN0IHdhbnQgdGhlIFBBTSBhY2NvdW50IGFuZCBzZXNzaW9uIGNoZWNrcyB0byBydW4gd2l0aG91dAojIFBBTSBhdXRoZW50aWNhdGlvbiwgdGhlbiBlbmFibGUgdGhpcyBidXQgc2V0IFBhc3N3b3JkQXV0aGVudGljYXRpb24KIyBhbmQgQ2hhbGxlbmdlUmVzcG9uc2VBdXRoZW50aWNhdGlvbiB0byAnbm8nLgojIFdBUk5JTkc6ICdVc2VQQU0gbm8nIGlzIG5vdCBzdXBwb3J0ZWQgaW4gUmVkIEhhdCBFbnRlcnByaXNlIExpbnV4IGFuZCBtYXkgY2F1c2Ugc2V2ZXJhbAojIHByb2JsZW1zLgpVc2VQQU0geWVzIAoKI0FsbG93QWdlbnRGb3J3YXJkaW5nIHllcwojQWxsb3dUY3BGb3J3YXJkaW5nIHllcwojR2F0ZXdheVBvcnRzIG5vClgxMUZvcndhcmRpbmcgeWVzCiNYMTFEaXNwbGF5T2Zmc2V0IDEwCiNYMTFVc2VMb2NhbGhvc3QgeWVzCiNQZXJtaXRUVFkgeWVzCiNQcmludE1vdGQgeWVzCiNQcmludExhc3RMb2cgeWVzCiNUQ1BLZWVwQWxpdmUgeWVzCiNVc2VMb2dpbiBubwpVc2VQcml2aWxlZ2VTZXBhcmF0aW9uIG5vCiNQZXJtaXRVc2VyRW52aXJvbm1lbnQgbm8KI0NvbXByZXNzaW9uIGRlbGF5ZWQKI0NsaWVudEFsaXZlSW50ZXJ2YWwgMAojQ2xpZW50QWxpdmVDb3VudE1heCAzCiNTaG93UGF0Y2hMZXZlbCBubwojVXNlRE5TIHllcwojUGlkRmlsZSAvdmFyL3J1bi9zc2hkLnBpZAojTWF4U3RhcnR1cHMgMTA6MzA6MTAwCiNQZXJtaXRUdW5uZWwgbm8KI0Nocm9vdERpcmVjdG9yeSBub25lCiNWZXJzaW9uQWRkZW5kdW0gbm9uZQoKIyBubyBkZWZhdWx0IGJhbm5lciBwYXRoCiNCYW5uZXIgbm9uZQoKIyBBY2NlcHQgbG9jYWxlLXJlbGF0ZWQgZW52aXJvbm1lbnQgdmFyaWFibGVzCkFjY2VwdEVudiBMQU5HIExDX0NUWVBFIExDX05VTUVSSUMgTENfVElNRSBMQ19DT0xMQVRFIExDX01PTkVUQVJZIExDX01FU1NBR0VTCkFjY2VwdEVudiBMQ19QQVBFUiBMQ19OQU1FIExDX0FERFJFU1MgTENfVEVMRVBIT05FIExDX01FQVNVUkVNRU5UCkFjY2VwdEVudiBMQ19JREVOVElGSUNBVElPTiBMQ19BTEwgTEFOR1VBR0UKQWNjZXB0RW52IFhNT0RJRklFUlMKCiMgb3ZlcnJpZGUgZGVmYXVsdCBvZiBubyBzdWJzeXN0ZW1zClN1YnN5c3RlbQlzZnRwCS91c3IvbGliZXhlYy9vcGVuc3NoL3NmdHAtc2VydmVyCgojIEV4YW1wbGUgb2Ygb3ZlcnJpZGluZyBzZXR0aW5ncyBvbiBhIHBlci11c2VyIGJhc2lzCiNNYXRjaCBVc2VyIGFub25jdnMKIwlYMTFGb3J3YXJkaW5nIG5vCiMJQWxsb3dUY3BGb3J3YXJkaW5nIG5vCiMJUGVybWl0VFRZIG5vCiMJRm9yY2VDb21tYW5kIGN2cyBzZXJ2ZXI=
kind: Secret
metadata:
  labels:
    pg-cluster: fromcrd
    pgo-backrest-repo: "true"
  name: fromcrd-backrest-repo-config
  namespace: ${NS}
type: Opaque
EOF

# unset the *_KEY environmental variables
unset PUBLIC_KEY
unset PRIVATE_KEY

# create the required postgres credentials for the fromcrd cluster
$PGO_CMD -n $NS create -f $DIR/postgres-secret.yaml
$PGO_CMD -n $NS create -f $DIR/primaryuser-secret.yaml
$PGO_CMD -n $NS create -f $DIR/testuser-secret.yaml
$PGO_CMD -n $NS create -f $DIR/backrest-repo-config.yaml

# create the pgcluster CRD for the fromcrd cluster
$PGO_CMD -n $NS create -f $DIR/fromcrd.json
