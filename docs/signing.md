# Signing

The release job in `.github/workflows/ci.yml` archives the app with automatic signing and the `Apple Development` identity set in the project.
Export to App Store Connect then re-signs the archive through cloud signing, which needs no certificate on the runner.

The archive step does need a development certificate whose private key is in the runner's keychain.
GitHub's macOS runners start with an empty keychain, so without one Xcode creates a fresh "Apple Development: Created via API" certificate on every release.
Those pile up until the account reaches Apple's certificate limit and the archive fails with "Your account has reached the maximum number of certificates".
To prevent that, CI imports one fixed certificate before archiving.

## Secrets

All secrets live in the `testflight` deployment environment, which only `main` can deploy to.

| Secret | Content |
| --- | --- |
| `APPSTORE_CONNECT_API_KEY_ID` | the key ID, which is also part of the file name `AuthKey_<KEY_ID>.p8` |
| `APPSTORE_CONNECT_API_KEY_ISSUER_ID` | the issuer ID shown above the list of team keys |
| `APPSTORE_CONNECT_API_KEY_PRIVATE_KEY` | the content of `AuthKey_<KEY_ID>.p8` |
| `BUILD_CERTIFICATE_BASE64` | the `.p12` holding the certificate and its private key, base64 encoded |
| `P12_PASSWORD` | the password the `.p12` was exported with |
| `KEYCHAIN_PASSWORD` | any random string, used for the temporary keychain on the runner |

## Creating the certificate

Use the `Apple Development` type.
It is the identity the project signs with, so automatic signing picks it up.
The older `iOS App Development` type may be passed over, and Xcode would create a new certificate again.
An `Apple Distribution` certificate is not needed, since cloud signing already covers distribution at export.

The certificates in the developer portal cannot be reused, as the portal only hands out the public half.
Their private keys stayed on the runners that created them.
A new certificate starts from a private key you generate yourself, and Apple only ever sees the signing request built from it.

These steps work on any machine with OpenSSL, no Mac required.

1. Generate a private key and a certificate signing request in an empty scratch directory outside the repository:

   ```sh
   openssl genrsa -out ci.key 2048
   openssl req -new -key ci.key -out ci.csr -subj "/CN=vibetype CI/C=DE"
   ```

2. In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list), revoke stale "Created via API" certificates if the limit is reached.
3. Add a certificate of type **Apple Development**, upload `ci.csr`, and download the resulting `development.cer`.
4. Bundle the certificate and the key into a `.p12`, choosing a strong export password when prompted:

   ```sh
   openssl x509 -inform DER -in development.cer -out ci.pem
   openssl pkcs12 -export -legacy -inkey ci.key -in ci.pem -out ci.p12 -name "vibetype CI"
   ```

   The `-legacy` flag matters: macOS `security import` often rejects files encrypted with the OpenSSL 3 defaults.

5. Store the secrets:

   ```sh
   base64 -w0 ci.p12 | gh secret set BUILD_CERTIFICATE_BASE64 --repo maevsi/ios --env testflight
   gh secret set P12_PASSWORD --repo maevsi/ios --env testflight
   gh secret set KEYCHAIN_PASSWORD --repo maevsi/ios --env testflight --body "$(openssl rand -base64 24)"
   ```

6. Keep `ci.key` and `ci.p12` in a password manager if wanted, then delete the scratch directory.

## App Store Connect API key

Xcode uses the key to fetch provisioning profiles while archiving and to sign through the cloud while exporting.
Create a team key in [App Store Connect](https://appstoreconnect.apple.com/access/integrations/api) under Users and Access, Integrations, App Store Connect API.
Apple offers the `.p8` download only once, so store it right away.

```sh
gh secret set APPSTORE_CONNECT_API_KEY_PRIVATE_KEY --repo maevsi/ios --env testflight < AuthKey_<KEY_ID>.p8
gh secret set APPSTORE_CONNECT_API_KEY_ID --repo maevsi/ios --env testflight --body "<KEY_ID>"
gh secret set APPSTORE_CONNECT_API_KEY_ISSUER_ID --repo maevsi/ios --env testflight
```

## Share extension

The archive holds two targets, the app `si.maev.twa` and its share extension `si.maev.twa.share`, and CI signs both the same way.
They exchange shared images through the App Group `group.si.maev.twa`, which both entitlement files list.

Set this up once in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) before the first release that contains the extension:

1. Register the App Group `group.si.maev.twa`.
2. Register the App ID `si.maev.twa.share` if it does not exist yet.
3. Enable the App Groups capability on both App IDs and assign `group.si.maev.twa` to each.

Automatic signing then fetches a development profile for each target through the App Store Connect API key while archiving, and cloud signing covers both at export.

## Renewal

The certificate is valid for one year.
Repeat the steps above before it expires and replace the secrets.
Xcode fetches a matching development provisioning profile through the App Store Connect API key, so no profile needs to be stored.
