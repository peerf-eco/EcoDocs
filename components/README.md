# How to contribute component specification

Please follow the guidelines below:

1. Clone the repository and create branch with your component name, like `add/ComponentName`
2. Add new folder inside `components/` named with your component unique CID (Component ID) in UGUID format. If folder exists contact repository maintainers (PeerF)
3. Use ISO notation for language of the documents: de - German, en - English, fr - French, ru for Russian, etc and create a document unique code in `USPD` format (see reference below)
4. Fill in the document metadata fields at the top:
   - **USPD**: Your unique document number (e.g., `US.ECO.00015-01 90`)
   - **Name**: Component name (e.g., `Eco.Stack1`)
   - **CID**: Component ID - 32-character hex string (same as folder name)
   - **Short Description**: Brief description (max 300 characters)
   - **Category**: Component category (e.g., UTILITY, SYSTEM, etc.)
   - **Type**: Always `COMPONENT` for components
5. Save document in `.fodt` (Flat ODF Format) under name `LanguageCode.ECO.XXXXX-YY_90.fodt` (use LibreOffice or similar editor to SaveAs `.fodt`)
6. Create commit with message, like: `new ComponentName spec is added, in EN language`
7. Create GitHub pull request

## Automated Processing

After your pull request is merged:
- Documents are automatically converted to Markdown with VitePress frontmatter
- Files are deployed to language-specific directories based on filename prefix
- **USPD Registry** (`USPD_REGISTRY.md`) is automatically updated with your component metadata
- All metadata from your document appears in the registry for easy discovery

## USPD Registry

The repository maintains an automated registry of all documentation at `USPD_REGISTRY.md`. This registry:
- Lists all components with their USPD numbers, names, CIDs, and descriptions
- Updates automatically when documents are added or modified
- Provides a quick reference for all available documentation
- Sorted by USPD number for easy navigation

Example registry entry:
```
US.ECO.00007-01 : Eco.Stack1 : 18129B1DCF9248D9A7787F9206E2D6DC : implements in memory stack data structure FILO
```


# Reference on creation document unique number

## TLDR

USPD (Unified Standard for Project Documentation) number standard in Software:

US.ECO.XXXXX-YY 90 (with a space before "90"), where:
- FR, RU, DE for language of document used
- ECO - replace it with an your organization code, e.g. upto 5 capital letters or digits (can be 5 symbols of your company EcoOS marketplace id); use ECO if your are a student and your work is affiliated to PeerF / EcoOS.
- XXXXX - ordering number of this document in your organization, 1-99999 (ask maintainers/PeerF for ECO organization)
- YY is a current document version (revision), 0-99

If you use the USPD code in the filename:

```
US.ECO.XXXXX-YY_90.fodt # Component specification in English
RU.ECO.XXXXX-YY_90.fodt # Component specification in Russian
FR.ECO.XXXXX-YY_90.fodt # Component specification in French
DE.ECO.XXXXX-YY_90.fodt # Component specification in German
```

**Important**: The language prefix in the filename determines which language directory your documentation will be deployed to in the VitePress site.

## Detailed explanation

USPD (Unified Standard for Project Documentation - unique document number) - how to get it.

The number itself in general form looks like US.ECO.XXXXX-YY 90 [ZZ-N] (spaces before and after "90")

Explanations:

ECO is the developer code (up to 5 digits or letters, we can put from the developer company, product or the first 5 digits of the Id organization/store company as in the DB)

XXXXX - from 00001 to 99999 (document serial number within the organization) start with 00001 and increase by one

YY - from 01 to 99 (document revision number, version), put 01 where there is no version number

90 is our custom document format code for the component (not ISO / GOST). That is, where after a space there is 90 we leave these numbers, because there can be a number from 01 to 89 for standard documents: - technical specification, user manual, specification, etc. Therefore, from 90 to 99 is given for the user format, and this folder documents - "component specification" is assigned the custom document type 90

Optional codes:
ZZ - registration number - we do not use it yet

N - from 0 to 9 - we do not use it yet

That is, the ending of the number ZZ-N - is used if necessary, the document is assigned a document number of this type in ascending order from 01 to 99, the number of the part of the document in ascending order from 1 to 9. We do not need this yet.
