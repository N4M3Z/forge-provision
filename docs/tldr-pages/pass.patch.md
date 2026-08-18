- Re-encrypt the password store for a new GPG key:

`pass init {{new_key_id}}`

- Re-encrypt one password-store directory for a new GPG key:

`pass init -p {{directory}} {{new_key_id}}`

- Read a TOTP value from the pass-otp extension:

`pass otp {{entry}}`

- Run Git inside the password store:

`pass git {{arguments}}`
