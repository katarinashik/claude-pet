# storyboard frames for the task-done-flag pose: each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'g1'                 # typing
Set-ArmUp $true; Set-Flag $true 3 0; Set-Eyes 0 2 $false; Shot 'g2'         # raises the flag
Set-Flag $true 0 0; Set-Happy $true; Shot 'g3'                              # done! happy eyes
Set-Flag $true 0 1; $bob.Y = $PX; Shot 'g4'                                 # waves it, bounces
Set-Flag $true 0 0; $bob.Y = 0; Shot 'g5'
Set-Flag $true 0 1; $bob.Y = $PX; Shot 'g6'
$bob.Y = 0; Set-Flag $true 0 0; Set-Confetti $true; Shot 'g7'               # hover: confetti
Set-Confetti $false; Set-Happy $false; Set-Flag $false 0 0; Set-ArmUp $false; Set-Eyes 0 4 $false; Shot 'g8'   # back to work
