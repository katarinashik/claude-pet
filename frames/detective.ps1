# storyboard frames for the detective pose: each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'k1'                 # typing
Set-Deer $true -3; Set-Eyes 0 2 $false; Shot 'k2'                           # the hat comes down
Set-Deer $true 0; Set-Lens $true 0 0; Shot 'k3'                             # magnifying glass up
Set-Lens $true -1 1; Set-Clue '?'; Shot 'k4'                                # looks down at the laptop... ?
Set-Lens $true 0 0; Shot 'k5'                                               # ...looks around
Set-Lens $true 0 0; Set-Clue '!'; Shot 'k6'                                 # found it!
Set-Clue '!'; Set-Lens $true -1 0; Shot 'k7'                                # hover: the big eye looks at you
Set-Clue ''; Set-Lens $false 0 0; Set-Deer $true -3; Set-Eyes 0 4 $false; Shot 'k8'   # back to work
