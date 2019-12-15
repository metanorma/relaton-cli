## [Draft] - Relaton CLI

### What does it do?

* Fetch a standard document
* Extract bibdata from metanorma document

* Export relaton xml document to a html document
* Export relaton xml document to a yml document
* Export relaton xml document to new yml document

* Export relataon yml document to a html document
* Export relaton yml document to new html document
* Export relataon yml document to xml document
* Export relaton yml document to new xml document

* Concatenate relaton yml files to a xml document
* Splits relaton collections to individual files

### How does it fetches a document?

* User provides the standard id, and type as command
* The relaton cli check for the type or pass it to relaton
* Fetches the document and then print it out to the stdout

### How does relaton xml export works?

* It parses the string to a nokagiri xml document
* It extracts the data from xml and build a hash
* It build a bibdata/collection using that hash
* Once we have bibdata object then export it to html/yaml/newyaml

### How does relaton yaml export works?

