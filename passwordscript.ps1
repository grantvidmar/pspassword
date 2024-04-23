# Check if script is running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # Relaunch the script as administrator
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    exit
}

# Function to perform the user search
function SearchUsers {
  # Prompt user for search term (Surname)
  $searchTerm = Read-Host -Prompt "Enter the search term"

  # Remove non-alphabetic characters from the search term
  $cleanedSearchTerm = $searchTerm -replace "[^a-zA-Z]", ""

  # Search for user objects in the entire domain that match the cleaned search term
  $matchingUsers = Get-ADUser -Filter "Surname -like '$cleanedSearchTerm'" -Properties "SamAccountName", "Name", "Surname", "PasswordLastSet", "LockedOut", "Enabled" 

  # Display the results
  if ($matchingUsers.Count -gt 0) {
      Write-Host "Users found in the entire domain with the cleaned search term '$cleanedSearchTerm':" -ForegroundColor Green
      $index = 1
      $matchingUsers | ForEach-Object {
          Write-Host "$index. $($_.SamAccountName) - $($_.Name) - $($_.Surname)"
          $index++
      }

      # Allow the user to choose from the list if there are multiple results
      if ($matchingUsers.Count -gt 1) {
          $userChoice = Read-Host "Enter the number of the user you want to select"
          $selectedUser = $matchingUsers[$userChoice - 1]

          # Display detailed information about the selected user
Write-Host "Selected User Information:" -ForegroundColor Yellow
Write-Host "SamAccountName: $($selectedUser.SamAccountName)"

# Get date of last password reset
$passwordLastSet = $selectedUser.PasswordLastSet
Write-Host "Last Password Reset: $($passwordLastSet)"

# Get date of next password reset
$nextPasswordReset = $passwordLastSet + (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

# Check if the next password reset is before the current date
if ($nextPasswordReset -lt (Get-Date)) {
    Write-Host "Next Password Reset: $($nextPasswordReset) - Password reset overdue" -ForegroundColor Red
} else {
    Write-Host "Next Password Reset: $($nextPasswordReset)" -ForegroundColor Green
}

# Check if the account is locked
if ($selectedUser.LockedOut) {
    Write-Host "Account Locked: Yes" -ForegroundColor Red
} else {
    Write-Host "Account Locked: No" -ForegroundColor Green
}

# Check if the account is disabled
if (-not $selectedUser.Enabled) {
    Write-Host "Account Disabled: Yes" -ForegroundColor Red
} else {
    Write-Host "Account Disabled: No" -ForegroundColor Green
}
          
# Prompt user for action
$actionPrompt = @"
Select an action:
1. Unlock the account
2. Reset the password
3. Unlock the account and reset the password
4. Search again
"@ 

# Display the menu in orange
Write-Host $actionPrompt -ForegroundColor DarkYellow

# Prompt the user for their choice
$actionChoice = Read-Host "Enter the number of the action you want to perform"

          # Perform the selected action
          switch ($actionChoice) {
              1 { Unlock-ADAccount -Identity $selectedUser.SamAccountName }
              2 { 
                $passwordPolicy = Get-ADDefaultDomainPasswordPolicy
                Write-Host "Password Policy Requirements" -ForegroundColor Yellow
                Write-Host "Minimum Password Length: $($passwordPolicy.MinPasswordLength)" -ForegroundColor Red
                Write-Host "Password History Length: $($passwordPolicy.PasswordHistoryCount)" -ForegroundColor Red
                Write-Host "Complexity Requirements: $($passwordPolicy.ComplexityEnabled)" -ForegroundColor Red
                Write-Host "Lockout Threshold: $($passwordPolicy.LockoutThreshold)" -ForegroundColor Red
                Write-Host "Lockout Observation Window: $($passwordPolicy.LockoutObservationWindow)" -ForegroundColor Red
                Write-Host "Lockout Duration: $($passwordPolicy.LockoutDuration)" -ForegroundColor Red
                
                # Reset password and ensure the user does not need to change it at next login
                Set-ADAccountPassword -Identity $selectedUser.SamAccountName -Reset -PassThru | Set-ADUser -ChangePasswordAtLogon $false}
              3 {
                  Unlock-ADAccount -Identity $selectedUser.SamAccountName
                  $passwordPolicy = Get-ADDefaultDomainPasswordPolicy
                  Write-Host "Password Policy Requirements" -ForegroundColor Yellow
                  Write-Host "Minimum Password Length: $($passwordPolicy.MinPasswordLength)" -ForegroundColor Red
                  Write-Host "Password History Length: $($passwordPolicy.PasswordHistoryCount)" -ForegroundColor Red
                  Write-Host "Complexity Requirements: $($passwordPolicy.ComplexityEnabled)" -ForegroundColor Red
                  Write-Host "Lockout Threshold: $($passwordPolicy.LockoutThreshold)" -ForegroundColor Red
                  Write-Host "Lockout Observation Window: $($passwordPolicy.LockoutObservationWindow)" -ForegroundColor Red
                  Write-Host "Lockout Duration: $($passwordPolicy.LockoutDuration)" -ForegroundColor Red
                  
                  # Reset password and ensure the user does not need to change it at next login
                Set-ADAccountPassword -Identity $selectedUser.SamAccountName -Reset -PassThru | Set-ADUser -ChangePasswordAtLogon $false
              }
              4 { SearchUsers }
          }
      } else {
          # If there's only one result, automatically select it
          $selectedUser = $matchingUsers[0]
          Write-Host "Selected: $($selectedUser.SamAccountName) - $($selectedUser.Name) - $($selectedUser.Surname)" -ForegroundColor Yellow
      }
  } else {
      Write-Host "No users found in the entire domain with the cleaned search term '$cleanedSearchTerm'." -ForegroundColor Yellow
  }
}

# Loop to allow the user to go back to the search if nothing is found
do {
  # Call the search function
  SearchUsers

  # Prompt the user to repeat the search
  $repeatSearch = Read-Host "Do you want to search again? (yes/no)"

} while ($repeatSearch -eq 'yes' -or $repeatSearch -eq 'y' -or $repeatSearch -eq 'Y')
