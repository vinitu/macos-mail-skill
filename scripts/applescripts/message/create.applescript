-- Create a draft message (do not send).
-- argv: account to cc bcc sender subject body visible [attachment...]
-- `cc`, `bcc` and `sender` may be empty strings. `to`, `cc` and `bcc` accept a
-- comma-separated list. Attachments are absolute POSIX paths.
on run argv
	if (count of argv) < 8 then
		return "Usage: create.applescript <account> <to> <cc> <bcc> <sender> <subject> <body> <visible> [attachment...]"
	end if
	set accName to item 1 of argv
	set toList to my splitAddresses(item 2 of argv)
	set ccList to my splitAddresses(item 3 of argv)
	set bccList to my splitAddresses(item 4 of argv)
	set senderAddr to item 5 of argv
	set subj to item 6 of argv
	set bodyText to item 7 of argv
	set showWin to true
	if item 8 of argv is "false" or item 8 of argv is "0" then set showWin to false

	tell application "Mail"
		set accRef to account accName
		if senderAddr is "" then
			set accEmail to email addresses of accRef
			set senderAddr to (item 1 of accEmail) as text
		end if
		set newMsg to make new outgoing message with properties {subject:subj, content:bodyText, visible:showWin, sender:senderAddr}
		-- Mail drops a recipient every few runs when they are added in a tight loop
		-- (measured: 2 of 5 runs lost one of three Cc addresses). Add, verify, re-add.
		my addTo(newMsg, toList)
		my addCc(newMsg, ccList)
		my addBcc(newMsg, bccList)
		set missingAddrs to my missingFrom(newMsg, toList, ccList, bccList)
		if missingAddrs is not "" then error "Mail did not accept every recipient: " & missingAddrs
		if (count of argv) ≥ 9 then
			repeat with i from 9 to (count of argv)
				set p to item i of argv
				tell content of newMsg
					make new attachment with properties {file name:(POSIX file p)} at after the last paragraph
				end tell
			end repeat
			-- Mail needs a moment to read each file in before the draft is saved.
			delay 1
		end if
		-- Always save. A draft that is never saved is lost when the window closes,
		-- and with visible:false there is no window to close it from.
		save newMsg
	end tell
	return "draft created"
end run

-- Each class needs its own `make new`, so the retry is written out three times rather
-- than parameterised; AppleScript cannot take the recipient class as a variable.
on addTo(msgRef, addrList)
	repeat 4 times
		if my presentAll(msgRef, addrList, "to") then return
		repeat with a in addrList
			if not my present(msgRef, a as text, "to") then
				tell application "Mail" to tell msgRef to make new to recipient at end of to recipients with properties {address:(a as text)}
			end if
		end repeat
		delay 0.1
	end repeat
end addTo

on addCc(msgRef, addrList)
	repeat 4 times
		if my presentAll(msgRef, addrList, "cc") then return
		repeat with a in addrList
			if not my present(msgRef, a as text, "cc") then
				tell application "Mail" to tell msgRef to make new cc recipient at end of cc recipients with properties {address:(a as text)}
			end if
		end repeat
		delay 0.1
	end repeat
end addCc

on addBcc(msgRef, addrList)
	repeat 4 times
		if my presentAll(msgRef, addrList, "bcc") then return
		repeat with a in addrList
			if not my present(msgRef, a as text, "bcc") then
				tell application "Mail" to tell msgRef to make new bcc recipient at end of bcc recipients with properties {address:(a as text)}
			end if
		end repeat
		delay 0.1
	end repeat
end addBcc

on currentAddresses(msgRef, kind)
	set out to {}
	tell application "Mail"
		if kind is "to" then
			set rs to to recipients of msgRef
		else if kind is "cc" then
			set rs to cc recipients of msgRef
		else
			set rs to bcc recipients of msgRef
		end if
		repeat with i from 1 to count of rs
			set end of out to (address of (item i of rs)) as text
		end repeat
	end tell
	return out
end currentAddresses

on present(msgRef, addr, kind)
	repeat with c in my currentAddresses(msgRef, kind)
		if (c as text) is addr then return true
	end repeat
	return false
end present

on presentAll(msgRef, addrList, kind)
	repeat with a in addrList
		if not my present(msgRef, a as text, kind) then return false
	end repeat
	return true
end presentAll

on missingFrom(msgRef, toList, ccList, bccList)
	set out to ""
	repeat with a in toList
		if not my present(msgRef, a as text, "to") then set out to out & "to:" & (a as text) & " "
	end repeat
	repeat with a in ccList
		if not my present(msgRef, a as text, "cc") then set out to out & "cc:" & (a as text) & " "
	end repeat
	repeat with a in bccList
		if not my present(msgRef, a as text, "bcc") then set out to out & "bcc:" & (a as text) & " "
	end repeat
	return out
end missingFrom

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
