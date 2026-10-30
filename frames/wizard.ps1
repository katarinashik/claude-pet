# storyboard frames for the wizard pose: each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'w1'                 # typing
Set-Hat $true -3; Set-Eyes 0 2 $false; Shot 'w2'                            # the hat comes down
Set-Hat $true 0; Set-Wand $true 0; Shot 'w3'                                # wand up
Set-Wand $true 1; Shot 'w4'                                                 # sparkles
Set-Wand $true 2; Set-Wink $true; Shot 'w5'                                 # wink
Set-Wink $false; Set-Wand $false 0; Set-Eyes 0 4 $false; Shot 'w6'          # types on, still a wizard
Set-Wand $true 3; Set-Wink $true; Set-Eyes 0 2 $false; Shot 'w7'            # hover: all the sparkles and a wink
Set-Wink $false; Set-Wand $false 0; Set-Hat $true -3; Shot 'w8'             # the hat goes off
