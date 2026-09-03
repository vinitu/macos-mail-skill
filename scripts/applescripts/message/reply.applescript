-- Reply to a message. argv: account mailbox index replyBody [visible] [attachment...]
-- Attachments are absolute POSIX paths; every argument after `visible` is treated as one.
on run argv
	if (count of argv) < 4 then
		return "Usage: reply.applescript <account> <mailbox> <index> <replyBody> [visible] [attachment...]"
	end if
	set accName to item 1 of argv
	set mbName to item 2 of argv
	set idx to item 3 of argv as integer
	set replyBody to item 4 of argv
	set showWin to true
	if (count of argv) ≥ 5 and (item 5 of argv is "false" or item 5 of argv is "0") then set showWin to false

	tell application "Mail"
		set m to message idx of mailbox mbName of account accName
		set replyMsg to reply m with opening window
		set content of replyMsg to replyBody
		set visible of replyMsg to showWin
		if (count of argv) ≥ 6 then
			repeat with i from 6 to (count of argv)
				set p to item i of argv
				tell content of replyMsg
					make new attachment with properties {file name:(POSIX file p)} at after the last paragraph
				end tell
			end repeat
			-- Mail needs a moment to read each file in before the draft is saved.
			delay 1
			save replyMsg
		end if
	end tell
	return "draft created"
end run
