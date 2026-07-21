# Dataset Licenses

This repository does not redistribute source datasets. It provides download and transform scripts only.

## 1) PaySim (`ealaxi/paysim1` on Kaggle)

- License: CC BY-SA 4.0
- Use: transaction simulation for `TXN` and declined or fraud mapping in UC3

## 2) LendingClub (`wordsforthewise/lending-club` on Kaggle)

- License terms: Kaggle Terms of Service and the dataset page terms
- Note: the raw dataset is downloaded by script at build time and should not be committed
- Use: application lifecycle (`STARTED`, `SUBMITTED`, `ABANDONED`) for UC2

## 3) Banking77 (`hwassner/banking77`, equivalent HF `PolyAI/banking77`)

- License: CC BY 4.0
- Use: seed conversation intent text for synthetic transcript generation

## 4) UCI Bank Marketing

- Source: https://archive.ics.uci.edu/static/public/222/bank+marketing.zip
- License: CC BY 4.0
- Use: product and offer enrichment plus campaign outcome context

## Redistribution Policy

- Commit scripts only.
- Do not commit CSV, ZIP, or model binaries.
- `.gitignore` blocks common data artifacts and credentials.

## Note

The merged documentation in this demo references the datasets above, but it does not bundle them. Keep the data boundary explicit when sharing or reviewing the repository.
