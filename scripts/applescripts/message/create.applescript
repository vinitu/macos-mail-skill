-- Create a draft message (do not send). argv: account toAddress subject body [visible] [attachment...]
-- Attachments are absolute POSIX paths; every argument after `visible` is treated as one.
on run argv
	if (count of argv) < 4 then
		return "Usage: create.applescript <account> <to> <subject> <body> [visible] [attachment...]"
	end if
	set accName to item 1 of argv
	set toAddr to item 2 of argv
	set subj to item 3 of argv
	set body to item 4 of argv
	set showWin to true
	if (count of argv) ≥ 5 and (item 5 of argv is "false" or item 5 of argv is "0") then set showWin to false

	tell application "Mail"
		set accRef to account accName
		set accEmail to email addresses of accRef
		set senderAddr to item 1 of accEmail
		set newMsg to make new outgoing message with properties {subject:subj, content:body, visible:showWin, sender:senderAddr}
		tell newMsg
			make new to recipient at end of to recipients with properties {address:toAddr}
		end tell
		if (count of argv) ≥ 6 then
			repeat with i from 6 to (count of argv)
				set p to item i of argv
				tell content of newMsg
					make new attachment with properties {file name:(POSIX file p)} at after the last paragraph
				end tell
			end repeat
			-- Mail needs a moment to read each file in before the draft is saved.
			delay 1
			save newMsg
		end if
	end tell
	return "draft created"
end run
