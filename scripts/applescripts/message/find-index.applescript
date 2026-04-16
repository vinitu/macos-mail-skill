-- Find the current index of a message by its message-id. argv: account mailbox message-id
on run argv
	if (count of argv) < 3 then error "Usage: find-index.applescript <account> <mailbox> <message-id>"
	set accName to item 1 of argv
	set mbName to item 2 of argv
	set targetId to item 3 of argv

	tell application "Mail"
		set mb to mailbox mbName of account accName
		set msgCount to count of messages of mb
		repeat with i from 1 to msgCount
			set msgRecord to message i of mb
			set msgId to ""
			try
				set msgId to message id of msgRecord as text
			end try
			if msgId is targetId then
				return i as text
			end if
		end repeat
	end tell

	error "Message not found: " & targetId
end run
