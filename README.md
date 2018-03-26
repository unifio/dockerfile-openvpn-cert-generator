# dockerfile-openvpn-cert-generator
A containerized openvpn SSL certificate generator with support for easy-rsa v2 and v3 for backward compatibility. Contains a script wrapper (/usr/bin/vpn_generate_certs) for generating server, client keys, and client OpenVPN configs (*.ovpn) with easyrsa2
___
## `vpn_generate_certs`

The `vpn_generate_certs` is a utility script to help bootstrap a set of certs and configs to assist in quickly getting getting an OpenVPN server/client configuration running. By default, it generates the following:

1. ~~(If the values `S3_REGION` and `S3_CERT_ROOT_PATH` are non-empty strings) Pull down the contents of the s3 path + `S3_DIR_OVERRIDE` (default: "most recent" directory) into the `KEY_DIR` using `awscli` credentials.~~
  * Something seems to be broken with the pulling logic. Pull existing certs down into the volume for mounting before attempting to generate and push new certs.
1. A root 4096-bit RSA CA cert (`ca.crt` and `ca.key`). The `ca.key` should be sorted in a safe place only for administrative uses.
1. A server cert signed by the CA above, as well as the server key (`server.key` should similarly be stored in s safe place only for administrative uses)
1. Diffie-Hellman parameters (4096-bit) for OpenVPN
1. A valid client cert, key, signing request and ovpn configuration file (client.crt, client.key, client.csr, client.ovpn), as well as a tarball that packages up all 4.
1. An invalid client cert, `dummy.*` to initialize the `crl.pem` file.
1. `index.txt` and `serial` for the EasyRSA utility.
1. (If the values `S3_REGION`, `S3_CERT_ROOT_PATH` are non-empty strings, and `S3_PUSH_DRYRUN` is not falsy) Push up the contents of the `KEY_DIR` to `S3_CERT_ROOT_PATH/<YYYYMMDD-HHMMSSZ>-<dir contents sha>` into the using `awscli` credentials.

If any of the files exist in the mounted directory (by default `/root/easy-rsa-keys/`), the script will attempt to use the files that currently exist.

* The script can be run multiple times to update an existing set of certs, add more client certs, or revoke client certs.
* The `index.txt` and `serial` files must be present in an existing `KEY_DIR`. The files are created automatically along with the directory if the `KEY_DIR` directory itself did not exist at the time of executing the script.
* This script does not generate the server configuration file (server.conf) for the OpenVPN server. Our openvpn-server docker image (unifio/docker-openvpn) allows these values to be set on the fly.

### Defaults and overrides:
Environment variables that one can use to override the built in defaults.
- `KEY_DIR` (/root/easy-rsa-keys) - is the directory where all the generated files can be found after running the script. It's intentionally pointed at a non-existent directory to have a new `index.txt` and `serial` be automatically generated. In the case of updating existing sets of certs generated via the EasyRSA utility, make sure these files exist in the mounted/mapped directory.
  * The tool has some issues when mapping this directory elsewhere. The volume mount should mount into the `/root/ directory and it's best to leave the `KEY_DIR` alone.
- `KEY_SIZE` (4096) - controls the RSA-bit size for both the Diffie-Hellman paramaters and the certificates.
- `CA_EXPIRE` (3650) - used by easyRSA's `pkitool`. Controls the number of days from the day the CA cert is generated until it expires. For usage simplicity, the cert is set to expire very far in the future (10 years). For security purposes, it'd be wise to lower this and figure out a certificate rotation policy.
  * The `/usr/bin/vpn_list_certs` tool is useful for checking the validity and expiration of certs
- `KEY_EXPIRE` (3650) - used by easyRSA's `pkitool`. Controls the number of days from the day the server and client cert is generated until it expires (10 years). For usage simplicity, the cert is set to expire very far in the future. For security purposes, it'd be wise to lower this and figure out a certificate rotation policy.
  * The `/usr/bin/vpn_list_certs` tool is useful for checking the validity and expiration of certs
- `KEY_COUNTRY` (US), `KEY_PROVINCE` (CA) `KEY_CITY` (San Francisco), `KEY_ORG` (Fort-Funston), `KEY_EMAIL` (cert-admin@example.com), `KEY_NAME` (EasyRSA) - Are all parameters use in the openssl certificate signing request for both server and client certs. These don't affect the operation of the OpenVPN server, but it's best to change these to values that match your organization for identification purposes.
- `ACTIVE_CLIENTS` (client) - is a comma-delimited list of active, valid client certs for the script to generate. The values here will generate client certs matching the comma-delimited name values.
  * The order of the client will affect the order the certs are generated, and correspond with their respective values in the `index.txt` and `serial` files. It's best not to change the order of existing certs once they are set.
  * `dummy` is the built in value that should cannot be used.
- `REVOKED_CERTS` ('') - is a comma-delimited list of certs to revoke. Typically, this should be a subset of the values from the `ACTIVE_CLIENTS` list.
  * A revoked client should stay in the `ACTIVE_CLIENTS` list, to avoid the confusion in accidentally generating another certificate with the same name.
- `OPENVPN_DEV` (tun) - controls the value generated in the client *.ovpn files for `dev`. For more information, see the documentation for openvpn regarding the `--dev` option`. This value needs to match the value used in the server configuration (which is not generate as part of these scripts).
- `OPENVPN_PROTO` (tcp) - controls the value generated in the client *.ovpn files for `dev`. For more information, see the documentation for openvpn regarding the `--proto` option`. This value needs to match the value used in the server configuration (which is not generate as part of these scripts).
  * This values differs from the OpenVPN default to work better with AWS load balancers, allowing the OpenVPN server to run in something of a High-Availablity mode.
- `OPENVPN_HOST` (localhost) - controls the value generated in the client *.ovpn files for `remote`. For more information, see the documentation for openvpn regarding the `--remote host [port]` option`. This value needs to match a resolvable hostname/IP for the OpenVPN server.
- `OPEVNPN_RESOLV_RETRY` (infinite) - controls the value generated in the client *.ovpn files for `resolve-retry`. For more information, see the documentation for openvpn regarding the `--resolve-retry` option`. By default, the clients are set to retry indefinitely to accommodate remote users that might be on a non-reliable connection (laptop users).
- `OPENVPN_COMP_LZO` (yes) - controls the value generated in the client *.ovpn files for `comp-lzo`. For more information, see the documentation for openvpn regarding the `--comp-lzo` option`. This value needs to match the value used in the server configuration (which is not generate as part of these scripts).
  - `--comp-lzo` has been marked for depreciation by the OpenVPN team in favor of `--compress lzo|lz4` that supports multiple line compression options in version OpenVPN 2.4+. This needs to be updated for future versions.
- `OPENVPN_VERB` (3) - controls the value generated in the client *.ovpn files for `verb`. For more information, see the documentation for openvpn regarding the `--verb` option. This value is only written in the client *.ovpn files and will only affect the client logging verbosity.
- `FORCE_CERT_REGEN` ('false') - Is used to ignore all the contents in the `KEY_DIR`, `rm -rf` them and force the script to re-run, regenerating everything in the script.
- `S3_PUSH_DRYRUN` ('false') - Is used by the `awscli` when pushing certs up to the s3 path to toggle the `--dryrun` flag. Ignored if `S3_REGION` and `S3_CERT_ROOT_PATH` is not set.
- `S3_REGION` ($AWS_DEFAULT_REGION) - Is used by the `awscli`.
- `S3_CERT_ROOT_PATH` ('') - Is used by the `awscli` to determine where to pull the certs from. The values should look something like `s3://some-example-bucket/optional-path`. The parsing is a bit finicky, so if it's a just a root level bucket, you should have a trailing slash. Otherwise, if it's a sub-directory of a root bucket, it should be like the format above.
- `S3_DIR_OVERRIDE` ('') - Is used during the S3 path pulling phase above to force the certs to be pulled from a specific sub-path of `S3_CERT_ROOT_PATH`, instead of attempting to pull from the "latest" timestampped directory (latest is determined via a name-sort, and assumes that the directories are named in a `YYYYMMDD-HHMMSSZ` format to facilitate name/time sorting)
  * It's best to set this manually, or monitor the cert generation process as it runs to avoid any surprises.
  * This only affects the pull process, not the s3 push process.

### Notes:
- Be aware, that values in the client *.ovpn files can always be change either manually, or programmatically via the OpenVPN client being used, once the files have be distributed to the clients.
- Some documentation for some of the `OPENVPN_*` values above can be found the generated *.ovpn files.
- Despite the tool maintaining different snapshots of the certificate state in s3, this is not a valid way to "revoke" certs due to how OpenSSL works.
- If you're using the awscli s3 push/pull functionality, make sure the appropriate `awscli` credentials are available (instance-role, `AWS_ACCESS_TOKEN`, etc).

---
## `vpn_list_certs`

The `vpn_list_certs` script is an adaptation of https://github.com/kylemanna/docker-openvpn/blob/master/bin/ovpn_listclients script that uses the `openssl` tool to list the name, date generated, date expiry, and validity of certs. It targets the `KEY_DIR` directory and assumes that all cert files (ca, server/client signed certs) are all in the same directory.

---
## Example usage:
```
docker run \
  -v ${PWD}/tmp:/root \
  -e KEY_SIZE=1024 \
  unifio/openvpn-cert-generator \
  vpn_generate_certs
```
  * Generate a set of certs in `${PWD}/tmp/easy-rsa-keys`.
  * Use 1024-bit keys for DH params, SSL cert complexity.
___
```
docker run \
  -v ${PWD}/tmp:/root` \
  unifio/openvpn-cert-generator \
  vpn_list_clients
```
  * List cert status in `${PWD}/tmp/easy-rsa-keys`.
___
```
aws s3 cp s3://some-example-bucket/test/20180326-051613Z-a74cbd8ef5206f4d83c17f3d3accfab0/ tmp/foo/ --recursive
docker run \
  -v ${PWD}/tmp/foo:/root/easy-rsa-keys \
  -e AWS_ACCESS_KEY_ID=xxx \
  -e AWS_SECRET_ACCESS_KEY=xxx \
  -e S3_REGION=us-east-1 \
  -e S3_CERT_ROOT_PATH=s3://some-example-bucket/test \
  -e KEY_SIZE=1024 \
  unifio/openvpn-cert-generator \
  vpn_generate_certs
```
  * Use ${PWD}/tmp/foo as the starting base for generating/updating the cert list
  * Use 1024-bit keys for DH params, SSL cert complexity.
  * After updating the certs, push the certs up to the s3://some-example-bucket/test/\<some new directory\>
___
```
docker run -it \
  -v ${PWD}/tmp:/root \
  --env-file=.env \
  -e AWS_ACCESS_KEY_ID=xxx \
  -e AWS_SECRET_ACCESS_KEY=xxx \
  -e S3_REGION=us-east-1 \
  -e S3_CERT_ROOT_PATH=s3://some-example-bucket/some-non-existant-path \
  -e KEY_SIZE=1024 \
  -e ACTIVE_CLIENTS=client,foo \
  -e FORCE_CERT_REGEN=true \
  foo/openvpn-cert-generator \
  vpn_generate_cert
```
  * `rm -rf` files in ${PWD}/tmp/easy-rsa-keys, if any.
  * Generate a set of certs in `${PWD}/tmp/easy-rsa-keys`. Generate client certs and configs for "client", and "foo"
  * Use 1024-bit keys for DH params, SSL cert complexity.
  * Push certs into s3://some-example-bucket/some-non-existant-path/\<some date\>-\<some sha\>
