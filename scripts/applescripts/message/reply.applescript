-- Reply to a message. argv: account mailbox index replyBody [visible]
on run argv
	if (count of argv) < 4 then
		return "Usage: reply.applescript <account> <mailbox> <index> <replyBody> [visible]"
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
	end tell
	return "draft created"
end run
