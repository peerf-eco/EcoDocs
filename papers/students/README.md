# How to upload diplomas and papers

please follow the fuidline below:

1. clone the repository and create branch with your name, like `add/NameSurname`
2. add folder with your name for the document. if folder exists and contains document, create new folder by adding the unique suffix, like: `NameSurname_2`
3. create language subfolders. Use ISO notation for language of the document: de - Germain, en - English, fr - France, ru for Russian, etc
4. create a document's unique code in `ESPD` format (see reference below); add that number to all documents being added, as a new line under the doc's header, like:
`ESPD: Your_ESPD`
5. save document in `.fodt` (Flat ODF Format) under name `Your_ESPD_number.fodt` and place into corresponding language subfolders (use LibraOffice or similar editor to SaveAs `.fodt`)
6. create commit with message, like: `dimploma of NameSurname is added, in en language`
7. create GitHub pull request

# Reference on creation document unique number

## TLDR

ESPD number standard:

US.ECO.XXXXX-YY 90 (with a space before "90"), where:
- FR, RU, DE for language of document used
- ECO - the PeerF code as an organization upto 5 capital letters/digits (can be 5 symbols of your company EcoOS marketplace id), use ECO if your are a student and your work is affiliated to PeerF / EcoOS.
- XXXXX - ordering number of document in your organization, 1-99999 (ask maintainers/PeerF for ECO organization)
- YY is a current document version (revision), 0-99

if you use the ESPD code in the file:

US.ECO.XXXXX-YY_90.fodt # Component specification in English

RU.ECO.XXXXX-YY_90.fodt # Component specification in Russian

## DEtailed explanation

ESPD (unique document number) - how to get it.

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
