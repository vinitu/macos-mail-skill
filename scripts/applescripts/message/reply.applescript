-- Reply to a message.
-- argv: account mailbox index replyBody cc bcc replyAll visible [attachment...]
-- `cc` and `bcc` may be empty strings and accept a comma-separated list.
-- `replyAll` is "true"/"1" to copy every original recipient.
on run argv
	if (count of argv) < 8 then
		return "Usage: reply.applescript <account> <mailbox> <index> <replyBody> <cc> <bcc> <replyAll> <visible> [attachment...]"
	end if
	set accName to item 1 of argv
	set mbName to item 2 of argv
	set idx to item 3 of argv as integer
	set replyBody to item 4 of argv
	set ccList to my splitAddresses(item 5 of argv)
	set bccList to my splitAddresses(item 6 of argv)
	set replyAll to (item 7 of argv is "true" or item 7 of argv is "1")
	set showWin to true
	if item 8 of argv is "false" or item 8 of argv is "0" then set showWin to false

	tell application "Mail"
		set m to message idx of mailbox mbName of account accName
		set replyMsg to reply m with opening window reply to all replyAll
		set content of replyMsg to replyBody
		set visible of replyMsg to showWin
		-- Same flakiness as create.applescript: Mail drops a recipient every few runs when
		-- they are added in a loop. Add, verify, re-add, and fail loudly rather than send a
		-- reply that quietly lost a Cc.
		my addKind(replyMsg, ccList, "cc")
		my addKind(replyMsg, bccList, "bcc")
		set missingAddrs to ""
		repeat with a in ccList
			if not my present(replyMsg, a as text, "cc") then set missingAddrs to missingAddrs & "cc:" & (a as text) & " "
		end repeat
		repeat with a in bccList
			if not my present(replyMsg, a as text, "bcc") then set missingAddrs to missingAddrs & "bcc:" & (a as text) & " "
		end repeat
		if missingAddrs is not "" then error "Mail did not accept every recipient: " & missingAddrs
		if (count of argv) ≥ 9 then
			repeat with i from 9 to (count of argv)
				set p to item i of argv
				tell content of replyMsg
					make new attachment with properties {file name:(POSIX file p)} at after the last paragraph
				end tell
			end repeat
			-- Mail needs a moment to read each file in before the draft is saved.
			delay 1
		end if
		-- Always save, with or without attachments.
		save replyMsg
	end tell
	return "draft created"
end run

-- Duplicated from create.applescript on purpose: this repo has no AppleScript library
-- loading, and a runtime `load script` would add a path dependency to every command.
on addKind(msgRef, addrList, kind)
	repeat 4 times
		set done to true
		repeat with a in addrList
			if not my present(msgRef, a as text, kind) then set done to false
		end repeat
		if done then return
		repeat with a in addrList
			if not my present(msgRef, a as text, kind) then
				tell application "Mail"
					if kind is "cc" then
						tell msgRef to make new cc recipient at end of cc recipients with properties {address:(a as text)}
					else
						tell msgRef to make new bcc recipient at end of bcc recipients with properties {address:(a as text)}
					end if
				end tell
			end if
		end repeat
		delay 0.1
	end repeat
end addKind

on present(msgRef, addr, kind)
	tell application "Mail"
		if kind is "cc" then
			set rs to cc recipients of msgRef
		else
			set rs to bcc recipients of msgRef
		end if
		repeat with i from 1 to count of rs
			if ((address of (item i of rs)) as text) is addr then return true
		end repeat
	end tell
	return false
end present

on splitAddresses(raw)
	if raw is "" then return {}
	set prevDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to ","
	set parts to text items of raw
	set AppleScript's text item delimiters to prevDelims
	set out to {}
	repeat with p in parts
		set trimmed to my trimText(p as text)
		if trimmed is not "" then set end of out to trimmed
	end repeat
	return out
end splitAddresses

on trimText(t)
	repeat while t begins with " "
		if length of t is 1 then return ""
		set t to text 2 thru -1 of t
	end repeat
	repeat while t ends with " "
		if length of t is 1 then return ""
		set t to text 1 thru -2 of t
	end repeat
	return t
end trimText
