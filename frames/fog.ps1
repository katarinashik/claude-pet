# storyboard frames for the fog scene (overcast or fog): each Shot is one frame
# Set-Fog thick drift wipe lampDx lit
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Set-Fog 1 -3 99 99 $false; Shot 'f1'   # typing, the first mist drifts in
Set-Fog 2 0 99 99 $false; Set-Eyes 0 4 $true; Shot 'f2'                                 # thick fog, he squints at the screen
Set-Fog 2 2 99 99 $false; Set-Eyes -1 4 $true; Shot 'f3'                                # can't see a thing
Set-Fog 2 3 -1 99 $false; Set-Eyes -1 5 $false; Shot 'f4'                               # wipes the laptop with a cloth...
Set-Fog 2 4 1 99 $false; Shot 'f5'                                                      # ...left and right
Set-Fog 2 5 99 3 $false; Set-Eyes 1 4 $false; Shot 'f6'                                 # pulls a little lamp in
Set-Fog 2 6 99 0 $true; Set-Happy $true; Shot 'f7'                                      # click: light!
Set-Happy $false; Set-Fog 2 7 99 0 $true; Set-Eyes 0 4 $false; Shot 'f8'                # types on in the lamp light
# the fog lifts
Set-Fog 1 8 99 0 $true; Set-Eyes 0 2 $false; Shot 'f9'                                  # it thins out, he looks up
Set-Fog 0 0 99 0 $false; Shot 'f10'                                                     # clear: lamp off
Set-Fog 0 0 99 3 $false; Set-Eyes 0 4 $false; Shot 'f11'                                # the lamp slides away
Set-Fog 0 0 99 99 $false; Shot 'f12'                                                    # back to work
