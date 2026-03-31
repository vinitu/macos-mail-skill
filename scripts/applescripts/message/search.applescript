-- Search messages in mailbox. argv: account mailbox search_mode value
on run argv
	if (count of argv) < 4 then error "Usage: search.applescript <account> <mailbox> <search_mode> <value>"
	set accName to item 1 of argv
	set mbName to item 2 of argv
	set searchMode to item 3 of argv
	set searchVal to item 4 of argv

	tell application "Mail"
		try
			set mb to mailbox mbName of account accName
		on error
			error "Mailbox not found: " & mbName & " in account " & accName
		end try

		set output to ""
		set firstMatch to true
		set totalCount to count of messages of mb
		
		set matchCount to 0
		-- Search in chunks from most recent
		set chunkSize to 500
		set currentBatchEnd to totalCount
		
		repeat while currentBatchEnd > 0 and matchCount < 20
			set currentBatchStart to currentBatchEnd - chunkSize + 1
			if currentBatchStart < 1 then set currentBatchStart to 1
			
			set batchMsgs to messages currentBatchStart through currentBatchEnd of mb
			
			-- Process batch backwards
			repeat with i from (count of batchMsgs) to 1 by -1
				set msgRecord to item i of batchMsgs
				set absoluteIndex to currentBatchStart + i - 1
				set isMatch to false
				if searchMode is "subject_contains" then
					if subject of msgRecord contains searchVal then set isMatch to true
				else if searchMode is "sender_contains" then
					if sender of msgRecord contains searchVal then set isMatch to true
				end if
				
				if isMatch then
					if firstMatch is false then set output to output & linefeed
					set output to output & my messageSummaryJson(msgRecord, accName, mbName, absoluteIndex)
					set firstMatch to false
					set matchCount to matchCount + 1
					if matchCount ≥ 20 then exit repeat
				end if
			end repeat
			
			set currentBatchEnd to currentBatchStart - 1
		end repeat
		
		return output
	end tell
end run

on messageSummaryJson(msgRecord, accName, mbName, messageIndex)
	using terms from application "Mail"
		set subjectValue to subject of msgRecord as text
		set senderValue to sender of msgRecord as text
		set rawDateReceivedValue to (date received of msgRecord)
		set rawReadValue to (read status of msgRecord)
		set rawFlaggedValue to (flagged status of msgRecord)
		set identityValue to (message id of msgRecord) as text
	end using terms from

	if identityValue is "" then
		set identityValue to accName & "/" & mbName & "/" & (messageIndex as text)
	end if

	set dateReceivedValue to my jsonNullable(rawDateReceivedValue)
	set readValue to my jsonBoolean(rawReadValue)
	set flaggedValue to my jsonBoolean(rawFlaggedValue)

	return "{" & "\"id\":" & my jsonString(identityValue) & "," & "\"account\":" & my jsonString(accName) & "," & "\"mailbox\":" & my jsonString(mbName) & "," & "\"index\":" & (messageIndex as text) & "," & "\"subject\":" & my jsonString(subjectValue) & "," & "\"sender\":" & my jsonString(senderValue) & "," & "\"date_received\":" & dateReceivedValue & "," & "\"read\":" & readValue & "," & "\"flagged\":" & flaggedValue & "}"
end messageSummaryJson

on jsonNullable(valueValue)
	if valueValue is missing value then return "null"
	set textValue to valueValue as text
	if textValue is "" then return "null"
	return my jsonString(textValue)
end jsonNullable

on jsonBoolean(booleanValue)
	if booleanValue then return "true"
	return "false"
end jsonBoolean

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
