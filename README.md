# PetMatch

## Petfinder API configuration (required)

This app uses the **Petfinder API v2**. Credentials are **not** stored in source code.

### Recommended (local dev): Scheme Environment Variable

In Xcode:

- Product → Scheme → Edit Scheme…
- Run → Arguments → Environment Variables
- Add:
  - `PETFINDER_CLIENT_ID` = `<your client id>`
  - `PETFINDER_CLIENT_SECRET` = `<your client secret>`

If credentials are missing, the app will show an error and won’t load pets.


# PetMatch
