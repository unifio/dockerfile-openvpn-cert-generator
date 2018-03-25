# dockerfile-openvpn-cert-generator
A containerized openvpn SSL certificate generator with support for easy-rsa v2 and v3 for backward compatibility. Contains a script wrapper (/generate_certs.sh) for generating server, client keys, and client OpenVPN configs (*.ovpn) with easyrsa2

## vpn_generate_certs

* The script can be run multiple times to update an existing set of certs.

* The `index.txt` and `serial` files must be present in an existing `KEY_DIR`. The files are created automatically along with the directory if the `KEY_DIR` directory itself did not exist at the time of executing the script
