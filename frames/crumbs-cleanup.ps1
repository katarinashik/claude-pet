# storyboard frames for the cleanup after the croissant or the sandwich: each Shot is one frame
Set-Paws 0 0 $false $false; Set-Crumbs 2; Set-Eyes -1 5 $false; Shot 'c1'          # all gone... crumbs everywhere
Set-Eyes 1 2 $false; Set-Clue '?'; Shot 'c2'                                         # where's the broom?
Set-Eyes -1 2 $false; Shot 'c3'                                                      # looks the other way
Set-Clue '!'; Set-Broom $true 0 -3; Set-Eyes 0 4 $false; Shot 'c4'                   # found it!
Set-Clue ''; Set-Broom $true -2 0; Set-Eyes -1 5 $false; Shot 'c5'                   # sweep to the left
Set-Broom $true 2 0; Set-Crumbs 3; Set-Puff $true; Shot 'c6'                         # and to the right, the crumbs fly off
Set-Broom $true 0 0; Set-Crumbs 0; Set-Puff $false; Set-Happy $true; Shot 'c7'       # clean
Set-Broom $false 0 0; Set-Happy $false; Set-Eyes 0 4 $false; Shot 'c8'               # back to work
