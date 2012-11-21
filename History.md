## ver. 0.0.5 2012-11-21

* [fixed] remove_orphans!()

## ver. 0.0.4 2012-11-21

* [changed] folders_hierarchy(): :validate param added
* [changed] folders_hierarchy(), folder_path(): orphan pathes marked with "<undefined>" parts
* [changed] 100% code coverage

## ver. 0.0.3 2012-11-19

* [added] Downloading files by absolute path
* [added] File download url added to the return hash of file_info(). Url is represented by the :url key
* [changed] Folder pathes now have leading slash
* [fixed] Base gem download functional didn't work when use :save_as param because of API changes month ago
* [changed] Integration file uploading test refactored

It has began. We have the features as follows:

* [added] Creating folders

## ver. 0.0.2 2012-11-18

Technical release. No features, no bug fixes.

## ver. 0.0.1 2012-11-17

It has began. We have the features as follows:

* [added] Creating folders
* [added] Removing folders
* [added] Moving folders
* [added] Uploading files
* [added] Removing files
* [added] Renaming files
* [added] Moving files
* [added] Viewing folders hierarchy
* [added] Dealing with orphan folders
* [added] Erasing all account data
* [added] Get file info
* [added] Folder/file identification by path
* [added] Integration tests (Forkers, be careful, account is fully erased before each test execution being performed!)