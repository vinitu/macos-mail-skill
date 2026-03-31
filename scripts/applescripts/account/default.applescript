tell application "Mail"
	set defaultAccount to first account
	return name of defaultAccount
end tell
