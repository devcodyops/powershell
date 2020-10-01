# Certificate Request

Powershell code to generate cert requests and submit to Microsoft CA for issuance
- ec384_bulk_cert_request.ps1 will bulk create device certificates from list specified in csv file
- cli ex: .\ec384_bulk_cert_request.ps1 -csvFile sourcefilelocation -IssuingCA CAHostname\CAName -CATemplate templatename