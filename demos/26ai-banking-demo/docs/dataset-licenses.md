# Dataset Licenses

This repository does **not** redistribute source datasets. It only provides download/transform scripts.

## 1) PaySim (`ealaxi/paysim1` on Kaggle)
- License: **CC BY-SA 4.0**
- Use: transaction simulation for `TXN` and declined/fraud mapping (UC3)

## 2) LendingClub (`wordsforthewise/lending-club` on Kaggle)
- License terms: **Kaggle Terms of Service / dataset page terms**
- Note: raw dataset is downloaded by script at build time and should not be committed
- Use: application lifecycle (`STARTED` / `SUBMITTED` / `ABANDONED`) for UC2

## 3) Banking77 (`hwassner/banking77`, equivalent HF `PolyAI/banking77`)
- License: **CC BY 4.0**
- Use: seed conversation intent text for synthetic transcript generation

## 4) UCI Bank Marketing
- Source: https://archive.ics.uci.edu/static/public/222/bank+marketing.zip
- License: **CC BY 4.0**
- Use: product/offer enrichment and campaign outcome context

## Redistribution Policy
- Commit scripts only.
- Do not commit CSV/ZIP/model binaries.
- `.gitignore` blocks common data artifacts and credentials.
