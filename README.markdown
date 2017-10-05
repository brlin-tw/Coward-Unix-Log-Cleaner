# Coward Unix Log Cleaner
<https://github.com/Lin-Buo-Ren/Coward-Unix-Log-Cleaner>

This Cleaner is so coward that it only removes rotated log files, truncates(empties) all *obvious* log files left, and nothing more.

This is useful for someone doesn't fully trust those powerful "X Cleaner" applications but still want to save some disk space, without the possiblity of breaking something.

## Warnings
* Don't use this utility in production systems as it will make system breach investigation difficult
* This utility doesn't clear non-obvious log files, for your privacy and other sakes you may want to check out the leftovers

## Features
### Cleaning System Logs
* Deletes file names with the following logrotated filename patterns under `/var/log`
	- `^.*/.+\.[[:digit:]]+(\.[[:alpha:]]+)?$`
	- `^.*/.+\.old$` (case-insensitive)
* Truncate/Empty files with filenames with the following log filename patterns under `/var/log`
	- `^.*/.+\.log$` (case-insensitive)

### Cleaning User Logs(not implemented yet)
* Deletes files with the following logrotated filename patterns under home directory(the pattern is stricter due to similar naming style of non-log files(id. est. libraries))
	- `^.*/.+\.log\.[[:digit:]]+(\.[[:alpha:]]+)?$` (case insensitive)
	- `^.*/.+\.old$` (case insensitive)
* Truncate/Empty files with filenames with the following log filename patterns
	- `^.*/.+\.log$` (case insensitive)

## License
GNU GPLv3+
