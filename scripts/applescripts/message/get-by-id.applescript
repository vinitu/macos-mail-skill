-- Get message details by message-id header. argv: messageId
-- Output: one JSON object.
on run argv
	if (count of argv) < 1 then error "Usage: get-by-id.applescript <message-id>"
	set targetId to item 1 of argv
	
	-- Strip <> if present for broader matching
	if targetId starts with "<" and targetId ends with ">" then
		set targetId to text 2 thru -2 of targetId
	end if

	tell application "Mail"
		set allAccounts to every account
		repeat with acc in allAccounts
			set allMailboxes to every mailbox of acc
			repeat with mb in allMailboxes
				try
					-- Direct search by message id is much faster
					set foundMsgs to (every message of mb whose message id contains targetId)
					if (count of foundMsgs) > 0 then
						set msgRecord to item 1 of foundMsgs
						return my messageJson(msgRecord, name of acc, name of mb, 1) -- index is arbitrary here
					end if
				end try
			end repeat
		end repeat
		error "Message not found with id: " & targetId
	end tell
end run

on messageJson(msgRecord, accName, mbName, messageIndex)
	using terms from application "Mail"
		set subjectValue to subject of msgRecord as text
		set senderValue to sender of msgRecord as text
		set contentValue to content of msgRecord as text
	end using terms from

	return "{" & "\"id\":" & my jsonString(accName & "/" & mbName) & "," & "\"subject\":" & my jsonString(subjectValue) & "," & "\"sender\":" & my jsonString(senderValue) & "," & "\"content\":" & my jsonString(contentValue) & "}"
end messageJson

on jsonString(textValue)
	return "\"" & my jsonEscape(textValue as text) & "\""
end jsonString

on jsonEscape(textValue)
	set escapedValue to textValue
	set escapedValue to my replaceText("\\", "\\\\", escapedValue)
	set escapedValue to my replaceText("\"", "\\\"", escapedValue)
	set escapedValue to my replaceText(return, "\\n", escapedValue)
	set escapedValue to my replaceText(linefeed, "\\n", escapedValue)
	set escapedValue to my replaceText(tab, "\\t", escapedValue)
	return escapedValue
end jsonEscape

on replaceText(findText, replaceTextValue, sourceText)
	set AppleScript's text item delimiters to findText
	set textItems to text items of sourceText
	set AppleScript's text item delimiters to replaceTextValue
	set replacedText to textItems as text
	set AppleScript's text item delimiters to ""
	return replacedText
end replaceText
