-- List the email addresses an account can send from. Returns one address per line.
-- argv: account
on run argv
	if (count of argv) < 1 then
		return "Usage: addresses.applescript <account>"
	end if
	set accName to item 1 of argv
	set output to ""
	tell application "Mail"
		set addrList to email addresses of account accName
	end tell
	if addrList is missing value then return ""
	repeat with i from 1 to count of addrList
		set output to output & (item i of addrList as text) & linefeed
	end repeat
	return output
end run
