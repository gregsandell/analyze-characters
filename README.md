analyze-characters
==================

Perl script that tallies up the count of ASCII, extended ASCII and UTF-8 characters in a file

This script was used to analyze the content of large (up to 1 GB) XML files representing product catalog data from various paid search clients.  
These files would subsequently be processed into other formats to be entered into various paid search platforms such as Google AdWords.
The process supported only plain 7-bit ASCII.  Any use of alternate characters sets such as the extended ascii portions of Latin-1 or WinLatin-1, 
or UTF-8, would cause Google search results to contain 'junk' characters.  This script would identify the line numbers on which such 
unacceptable characters occurred, allowing us to identify to the clients which products need correcting, or which we would correct ourselves.
