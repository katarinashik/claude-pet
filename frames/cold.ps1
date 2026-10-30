# storyboard frames for the cold scene (3 degrees or less): each Shot is one frame
# Set-Cold frost shiver breath scarf teaDy frame rosy
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Set-Cold 1 0 0 $false 99 0 $false; Shot 'k1'   # typing, frost on the laptop
Set-Cold 1 -1 1 $false 99 0 $false; Set-Eyes 0 4 $true; Shot 'k2'                                # brr, shivers, a puff of breath
Set-Cold 1 1 2 $false 99 0 $false; Shot 'k3'                                                     # brr brr
Set-Cold 1 0 1 $true 99 0 $false; Set-Eyes 0 3 $false; Shot 'k4'                                # wraps his scarf
Set-Cold 1 0 0 $true 0 0 $false; Set-Eyes 0 5 $false; Shot 'k5'                                  # a mug of hot tea
Set-Cold 1 0 0 $true -1 1 $false; Set-Happy $true; Shot 'k6'                                     # a sip, ahh
Set-Cold 1 0 0 $true 0 0 $true; Set-Heart $true; Shot 'k7'                                       # warm now, rosy cheeks
Set-Heart $false; Set-Happy $false; Set-Eyes 0 4 $false; Set-Cold 1 0 0 $true 99 1 $true; Shot 'k8'   # types on, snug
# it warms up
Set-Cold 2 0 0 $true 99 0 $true; Set-Eyes -1 5 $false; Shot 'k9'                                 # the frost drips away
Set-Cold 0 0 0 $false 99 0 $false; Set-Eyes 0 3 $false; Shot 'k10'                               # scarf off
Set-Eyes 0 4 $false; Shot 'k11'                                                                  # back to work
