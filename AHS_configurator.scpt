-- We are setting the Hostname to be the same as the ActiveDirectoryName
-- http://www.mactech.com/articles/mactech/Vol.20/20.12/RepeatLoops/index.html


-- i am using variables named such things as 'hostessKid' to avoid using variables with the same nomenclature as shell commands which are invoked
-- i.e., I consider making LocalHostName a variable to be poorly planned and possibly confusing
-- Does anyone else remember the Hostess Kid?  Or did they phase that out on Twinkie boxes by the 1990s?
-- setting the local admin account, which I assume you are using for this script.  It will come into use later.

try
	display dialog "Enter an admin account that will be used for this configuration" default answer " "
	set localAdmin to text returned of result
end try

-- first, turn on tap to click
-- it doesn't matter whether this works or not, really.  The point is to make sure we cache the admin credentials so we don't get asked again
-- http://osxdaily.com/2014/01/31/turn-on-mac-touch-to-click-command-line/
-- https://jasahackintosh.wordpress.com/2014/09/04/tweak-os-x-from-command-terminal/

do shell script "defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true" with administrator privileges
do shell script "defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1" with administrator privileges
do shell script "defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1" with administrator privileges


--- Here we take the local name and put it into the variable hostessKid
--- The Mac will inevitably name your computer after the name of the first local admin.
--- I think this is kind of lame.  Also, not very streamlined for inventory purposes.
try
	set hostessKid to do shell script "scutil --get LocalHostName"
on error -- for example if LocalHostName is not set
	set hostessKid to computer name of (system info)
end try

--- Here is where the script looks at your current computer's name and gives it back to you as variable hostessKid
display dialog "The current name of your computer is " & hostessKid with icon note buttons {"Change Name", "Leave the name as it is, please."} default button 1
if result = {button returned:"Change Name"} then
	try -- now it is accepting your input and it is going to verify that your new name is acceptable
		set countUp to 99 -- netbios limitations are still in effect.  names must be 15 characters or less
		repeat while countUp is greater than 15 -- we will loop through this until the name is 15 characters or less
			display dialog "Enter the Active Directory Name you want to give this Mac. Only alphanumeric characters and spaces will be accepted. Name MUST be 15 characters or less." default answer "currently " & hostessKid
			set newNameRaw to text returned of result -- the variable newNameRaw takes the input, and will process it to verify whether it has 15 characters or less
			set countUp to count (newNameRaw) -- this counts the characters in newNameRaw
			if countUp is greater than 15 then
				display dialog "must be 15 characters or less to bind to the University Active Directory.  Rules.  Sorry."
			end if
		end repeat
	end try
	-- if you have got this far, then newNameCooked will apply a SED command to remove all non-acceptable characters and empty spaces
	-- please note, this SED command is using BSD and POSIX standards.  Many SED and AWK commands in textbooks, Stack Overflow, etc, apply to GNU
	-- BNG+GNP :: Berkley Shell's not GNU | GNU's not Posix
	try
		set newNameCooked to do shell script ("<<<" & quoted form of newNameRaw & " sed -E 's/[[:space:]]*[^a-zA-Z0-9-]*//g'")
	end try
	
	display dialog "We're about to change the HostName, LocalHostName, and ComputerName to " & newNameCooked buttons {"Do it", "Ah, Cancel."} default button "Do it" cancel button "Ah, Cancel."
	do shell script "scutil --set ComputerName " & newNameCooked with administrator privileges
	do shell script "scutil --set HostName " & newNameCooked with administrator privileges
	do shell script "scutil --set LocalHostName " & newNameCooked with administrator privileges
	
	
	set hostessKid to computer name of (system info)
	display dialog "Hold on while we take some inventory information.  This information will go into a text file on your desktop.  Just so you know, your Mac's name (i.e., HostName) is now " & hostessKid buttons {"groovy", "not impressed"} default button "groovy"
	
else
	display alert "Okay, then.  We'll stay as we are and won't change the name.  Good times!  Hold on while we take some inventory information.  This information will go into a text file on your desktop." buttons {"Gotcha"} giving up after 5
end if

--- ### This will change the name of your HD volume to the name of the computer with "HD" tacked on the end
--- ### Because every Mac by default will have the volume named "Mac HD," which can be confusing when connecting Macs, or -- heaven forfend -- there are partitioned disks

set hdName to hostessKid & "HD"
tell application "Finder"
	set name of (path to startup disk) to hdName
end tell


---- ### This changes the defaults of the Mac so that the local hard drive and connected servers show up, by default, on the desktop
--- ###  dajames 7/29/14, 11:30 AM

tell application "Finder"
	set desktop shows hard disks of Finder preferences to true
	set desktop shows connected servers of Finder preferences to true
end tell

-- now I dump relevant system info into a text file on the desktop


--- #### BEGIN SYSTEM PROFILE SCRIPT
--- ##### THE PURPOSE OF THIS IS TO DUMP RELEVANT INFO INTO A TEXT SHEET
--- ###### AND DIALOG BOX FOR INVENTORY/AD DESCRIPTION PURPOSES

(*
	Daniel James dajames@illinois.edu 7/5/14, 9:41 AM
 	Script cribbed from http://macscripter.net/viewtopic.php?id=27652
	College of Applied Health Science
	University of Illinois, Urbana-Champaign
	*)



-- this is just to get the name of the local computer
try -- this is to get the HostName which should be the ADName, etc
	set HostName to do shell script "scutil --get LocalHostName"
on error -- for example if LocalHostName is not set
	set HostName to computer name of (system info)
end try

-- this is so that we can dump the info into a text file on the desktop
-- this is machine technical info for AD and for FABWEB, etc.

set profileName to HostName & "_details.txt"


set myOldDelimiters to AppleScript's text item delimiters --save the current ATID for later
set AppleScript's text item delimiters to {": "} --this is what separates a kind of data from the value. ATID is very useful for this sorta thing.

-- Display dialog hardware

set cereal to do shell script "system_profiler SPHardwareDataType | grep 'Serial Number' | awk '{print $4}'"
set model to do shell script "system_profiler SPHardwareDataType | grep 'Model Identifier' | awk '{print $3}'"
set cpu to do shell script "system_profiler SPHardwareDataType | grep 'Processor Name' | awk '{print $3,$4,$5,$6}'"
set mem to do shell script "system_profiler SPHardwareDataType | grep 'Memory' | awk '{print $2,$3}'"
set speed to do shell script "system_profiler SPHardwareDataType | grep 'Speed' | awk '{print $3,$4}'"

-- here come the various MAC (not , but MAC) addresses

set macMACWiFi to do shell script "ifconfig en0 | grep ether | sed -e s/ether/WiFi#/ | sed -e s/[[:space:]]//g"
-- en0 is always going to be WiFi on Macs.  At least of the time I type this
set macMACeth1 to do shell script "ifconfig en1 | grep ether | sed -e s/ether/Eth1#/g | sed -e s/[[:space:]]//g"
-- this should be the first ethernet adapter
set macMACeth2 to do shell script "ifconfig en2 | grep ether | sed -e s/ether/Eth2#/g | sed -e s/[[:space:]]//g"

set macMACp2p to do shell script "ifconfig p2p0 | grep ether | sed -e s/ether/VM#/g | sed -e s/[[:space:]]//g"
set macMACfw0 to do shell script "ifconfig fw0 | grep ether | sed -e s/ether/Tbolt#/g | sed -e s/[[:space:]]//g"
set macMACfw1 to do shell script "ifconfig fw1 | grep ether | sed -e s/ether/Tbolt2#/g | sed -e s/[[:space:]]//g"


set hardware to model & " | s/n#" & cereal & space & "| Ptag# | " & cpu & speed & space & mem & " RAM" & " | " & macMACWiFi & space & macMACeth1 & space & macMACeth2 & space & macMACp2p & space & macMACfw0


tell application "Finder"
	set fileExists to exists of (file profileName of (path to desktop))
	if fileExists is true then delete file profileName
end tell

set outputFile to ((path to desktop as text) & profileName)


try
	set fileReference to open for access file outputFile with write permission
	write hardware to fileReference
	close access fileReference
on error
	try
		close access file outputFile
	end try
end try


display dialog hardware



--- ########## END SYSTEM PROFILE SCRIPT

(*
	-- #### Hide the local admin account
	-- #### http://support.apple.com/en-us/HT203998	
	-- This is currently commented out.
	--- This will make the local admin account hidden, and exist under /var, not users.
	--- The local admin will thus not show up as an account visible in System Administration.
	
	set tricksyAdmins to "sudo dscl . create /Users/" & localAdmin & space & "IsHidden 1"
	
	try
		do shell script tricksyAdmins with administrator privileges
	end try
	-- The following command moves the home directory of local admin to /var, a hidden directory:
	
	try
		do shell script "mv /Users/" & localAdmin & space & " /var/" & localAdmin with administrator privileges
	end try
	-- The following command updates the user record of the hidden user with the new home directory path in /var:
	try
		do shell script "dscl . -create /Users/" & localAdmin & space & "NFSHomeDirectory /var/" & localAdmin with administrator privileges
	end try
	*)


-- #### Turn on Remote Admin
-- ##### For remote help through VNC
-- ###### http://themacadmin.com/script-enable-remote-management-ard/


do shell script "/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -users " & localAdmin & " -privs -all -restart -agent -menu" with administrator privileges


-- #################### Change Energy settings
-- #################### Lock screen after 20 minutes per domain policy	
-- #################### https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/pmset.1.html

-- Mac display turns off after 20 minutes
-- the -a switch indicates "all" for battery, UPS, and charger
try
	do shell script "pmset displaysleep -a 20" with administrator privileges
end try

-- Mac requires password when waking up from screen saver
--- https://discussions.apple.com/thread/1107321
---- You can disable this by running this shell script and change -int 1 to int 0
try
	do shell script "defaults write com.apple.screensaver askForPassword -int 1" with administrator privileges
end try


(*

############# BINDING SCRIPT FOR THE COLLEGE OF APPLIED HEALTH SCIENCES

GETTING THIS BLOODY THING TO WORK WAS REALLY THE WORK OF STANDING ON THE SHOULDER OF GIANTS

Special thanks to here: https://dgretch.wordpress.com/2014/08/15/os-x-applescript-to-rename-mac-and-bind-to-active-directory/

*)

set reBound to true -- this is the variable for the unbinding script
set reBind to true -- this is the variable for binding itself

try -- this is the beginning of the entire binding process.  The 'end try' is at the end of this script.  Everything else below is in between.
	
	
	---### BEGIN UNBINDING SCRIPT
	-- Is your Mac bound to AD already?
	-- this is to get what the current AD settings are
	-- dscl gets the AD argle bargle and puts it into variable 'blocko'
	-- awk sends the only relevant part, the second line to be output
	-- the two sed commands pipe the directory and search paths to be replaced with nothing.  They're just extra fluff and bits we don't care about.
	try
		set blocko to do shell script "dscl /Search -read / CSPSearchPath | grep /Active | awk '{ print $2}' | sed -e s/Directory// | sed -e s/All//" with administrator privileges
	end try
	
	
	try
		if blocko = "" then
			set reBound to false
			display dialog "You are not currently bound to an Active Directory." buttons {"Next Step."}
		else
			set reBound to true
		end if
	end try
	
	
	
	repeat while reBound is true
		
		--- ### This repeat loop runs an unbinder script
		--- ### If you are currently bound and choose to unbind for your current AD, this should do that.
		display dialog "This Mac is currently bound to a domain as follows: " & blocko & hostessKid & ". You'll have to unbind it if you want to rebind it to the current or new directory, or to bind it with a new name." buttons {"Unbind me!", "Leave it bound!"} with icon caution default button "Unbind me!"
		if result = {button returned:"Unbind me!"} then
			try
				display dialog "Enter a network user to unbind us from the domain" default answer " "
				set joiner to text returned of result
				
				display dialog "Password" default answer "" with hidden answer
				set noSecret to text returned of result
				
				do shell script "dsconfigad -force -remove -u " & joiner with administrator privileges
				set reBound to "false"
			end try
		else if result = {button returned:"Leave it bound!"} then
			set reBound to false
			set reBind to false -- if reBind is false, then we won't try to run the bind to AD, either
			-- the "leave it bound" response will cause us not to run the binding loop, either
			display dialog "Okay, then.  We are almost done!" buttons {"How nice."}
		end if
	end repeat
	
	---### END UNBINDING SCRIPT
	
	-- Now we present to the user the reBind process
	
	
	repeat while reBind is true
		
		display dialog "Now, we are attempting to bind to Active Directory the Mac with the name " & hostessKid with icon note buttons {"Carry On!", "This is too much for me to handle"} default button 1
		if result = {button returned:"Carry On!"} then
			
			-- display dialog "Enter the fully qualified name of Active Directory" default answer "ad.uillinois.edu"
			-- this used to take input and ask which domain one wanted to bind to.  No MORE!
			set doughMain to "ad.uillinois.edu"
			
			display dialog "Enter a user with privileges to bind to AD" default answer " "
			set joiner to text returned of result
			
			display dialog "Password" default answer "" with hidden answer
			set noSecret to text returned of result
			
			
			display dialog "We're about to bind to " & doughMain buttons {"Do it", "Cold feet"} default button "Do it" cancel button "Cold feet"
			
			try
				
				--Start binding
				-- Change AD.DOMAIN.COM to your AD domain
				-- Also change DC=ad,DC=domain,DC=com
				do shell script "dsconfigad -f -a " & hostessKid & space & "-domain " & doughMain & " = -u " & joiner & " -p " & noSecret & " -ou \"CN=Computers,DC=ad,DC=UILLINOIS,DC=edu\"" with administrator privileges
				
				try
					-- now the intangibles...
					
					do shell script "dsconfigad -alldomains enable -localhome enable -protocol smb -mobile enable -mobileconfirm disable -useuncpath enable" with administrator privileges
					
				end try
				
				try
					-- not even sure if this will be needed in the future
					
					do shell script "defaults write /Library/Preferences/DirectoryService/DirectoryService 'Active Directory' Active" with administrator privileges
					
					do shell script "plutil -convert xml1 /Library/Preferences/DirectoryService/DirectoryService.plist" with administrator privileges
				end try
				
				delay 10
				
				try
					do shell script "dscl /Search -create / SearchPolicy CSPSearchPath" with administrator privileges
					delay 5
					do shell script "dscl /Search -append / CSPSearchPath \"/Active Directory/All Domains\"" with administrator privileges
					do shell script "dscl /Search/Contacts -create / SearchPolicy CSPSearchPath" with administrator privileges
					do shell script "dscl /Search/Contacts -append / CSPSearchPath \"/Active Directory/All Domains\"" with administrator privileges
				end try
			end try
			
			-- I do this to help get DirectoryService running again in time to do the next steps (weird I know).
			-- This has been done in scripts before, so I am continuing that tradition.
			
			tell application "Terminal" to activate
			
			
			tell application "Terminal" to quit
			
			
			delay 1
			
			
			--- this is the end of the Domain Binding Script
			
			
			
			---############## LAST THING WE DO IS SHOW DIRECTORY UTILITY
			
			
			tell application "Directory Utility" to activate
			
			
			display dialog (do shell script "dsconfigad -show" with administrator privileges)
			
			set reBind to false -- now that we've run it, we won't cycle through again
			
			
		end if -- end of the "if" that starts the whole show
		
	end repeat -- end the repeat from reBind
	
end try -- this is the end try from the very beginning of the binding scripts




(*
		Adding user who will become an admin upon logging in.
		For faculty and staff who use this as their main machine which will eventually tie into their AppleID, this is where you can pre-stage the user
		Reference from here: http://support.apple.com/en-us/HT202112
		http://superuser.com/questions/214004/how-to-add-user-to-a-group-from-mac-os-x-command-line
		*)

try
	set reRun to true
	
	
	display dialog "Here is your chance to enter an Active Directory account which will automatically be made an admin upon login" with icon note buttons {"Yes, let's do that.", "No admins."}
	if result = {button returned:"Yes, let's do that."} then
		set reRun to true
	else if result = {button returned:"No admins."} then
		set reRun to false
	end if
	
	repeat while reRun is true
		try
			display dialog "Enter the name of the user who will be an admin on first login:" default answer "stevejobs"
			set majorDomus to text returned of result
			try
				do shell script "dseditgroup -o edit -a " & majorDomus & " -t user admin" with administrator privileges
				-- What is going on here is that we are caching the name of a potential user
				-- This does NOT create the account.  When the user logs on, the account is created from the Windows AD entry.
				-- This caches the account name (assuming you enter the correct NetID) with admin credentials BEFORE it is created
			end try
		end try
		
		try
			display dialog "Shall we enter another?" with icon note buttons {"Yes. Let's do so.", "No, Let's move on."} default button 1
			if result = {button returned:"Yes. Let's do so."} then
				set reRun to true
			else if result = {button returned:"No, Let's move on."} then
				set reRun to false
			end if
		end try
		
		
	end repeat
end try

--- ### End adding additional user


---### Adding and editing groups

-- do while loop begins
set reRun to true

-- I am adding 'ahs admins' as potential admins as default
set groupC to quote & "ahs admins" & quote


try
	display dialog "Here is your chance to give an active directory group account admin access by default" buttons {"No groups, thanks.", "Let's add groups."}
	if result = {button returned:"No groups, thanks."} then
		set reRun to false
	end if
end try


try
	repeat while reRun is true
		display dialog "Here is your chance to give an active directory group account admin access by default" default answer "ad group"
		set groupA to text returned of result
		set groupB to ("," & quote & groupA & quote) -- certain items with spaces must be within quotes.  this is the only way to get them in there.
		set groupC to groupC & groupB
		try
			display dialog "Shall we enter another?" with icon note buttons {"Enter another.", "Let's move on."} default button 1
			if result = {button returned:"Enter another"} then
				set reRun to true
				set groupC to groupC & "," & groupB
			else if result = {button returned:"Let's move on."} then
				set reRun to false
			end if
		end try
	end repeat
end try


-- we are now adding the groups.  Here we go...
try
	do shell script "dsconfigad -groups " & groupC with administrator privileges
end try


-- END ADDING GROUPS

---############## FILE VAULT CHECK
--- https://derflounder.wordpress.com/2014/08/13/filevault-2-institutional-recovery-keys-creation-deployment-and-use/#comment-13936
--- https://derflounder.wordpress.com/2013/10/22/managing-mavericks-filevault-2-with-fdesetup/
--- https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/dsconfigad.8.html
--- http://www.cnet.com/news/how-to-enable-filevault-remotely-in-os-x/



-- First, we check if FileVault is on.  If it is on, we skip setting it up, naturally.
-- As of now, checking for FileVault works, but turning it on does not seem to do so, properly.

set cryptoRiffic to do shell script "fdesetup status"
try
	if cryptoRiffic = "FileVault is On." then
		display dialog "It also looks like your Mac is encrypted.  You should be good to go." buttons {"Groovy."}
	else
		display dialog "This Mac is not encrypted.  If you wish to encrypt this Mac with FileVault, go under  -> System Preferences -> Security & Privacy -> FileVault.  You can turn on FileVault there.  Remember to save the key that it gives you, and store in a text file on the secure server on ahs-fs/Netarchive/Encryption Keys/FileVault.  Remember that you MUST ENABLE each user!  Even users who are administrators on the machine may need to be enabled in order to log back in to the Mac after it is rebooted.  YOU MUST ENABLE EACH USER!!!" with icon caution buttons {"Thank You, Drive Through, Please!"} giving up after 5
		
	end if
end try

---############## END FILE VAULT CHECK	

-- ################### OTHER ENVIRONMENT VARIABLES 
-- #################### Turn on the settings to default to User and Password screen at login

-- Display the login to display name and password so that users who have never logged on can initiate their profiles pulling down SID from the AD
-- https://jamfnation.jamfsoftware.com/discussion.html?id=8187

set loginYup to "defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME -bool true"

do shell script loginYup with administrator privileges
