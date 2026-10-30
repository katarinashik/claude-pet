# storyboard frames for the storm scene (thunderstorm): each Shot is one frame
# Set-Storm cloudDx bolt flash duck jump
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Set-Storm -6 $false $false 0 0; Shot 't1'            # typing, a dark cloud rolls in
Set-Storm 0 $false $false 0 0; Set-Rain 1 0; Set-Eyes 0 2 $false; Shot 't2'                             # heavy rain, he looks up
Set-Storm 0 $true $true 0 1; Set-Rain 1 1; $bang.Visibility = 'Visible'; Set-Eyes 0 1 $false; Shot 't3'  # FLASH! he jumps
$bang.Visibility = 'Hidden'; Set-Storm 0 $false $false 4 0; Set-Rain 1 0; Set-Eyes 0 4 $true; Shot 't4'  # hides behind the laptop, eyes shut
Set-Storm 0 $true $false 4 0; Set-Rain 1 1; Set-Eyes 0 4 $true; Shot 't5'                               # another bolt, he stays down
Set-Storm 0 $false $false 4 0; Set-Rain 1 0; Set-Eyes -1 4 $false; Shot 't6'                            # peeks left...
Set-Eyes 1 4 $false; Set-Rain 1 1; Shot 't7'                                                            # ...and right
# the storm passes
Set-Storm 6 $false $false 2 0; Set-Rain 0 0; Set-Eyes 1 3 $false; Shot 't8'                             # the cloud moves on, the rain stops, he comes up
Set-Storm 99 $false $false 0 0; Set-ArmUp $true; Set-Eyes 0 3 $true; Shot 't9'                          # phew, wipes his forehead
Set-ArmUp $false; Set-Happy $true; Set-Heart $true; Shot 't10'                                           # all good
Set-Heart $false; Set-Happy $false; Set-Eyes 0 4 $false; Shot 't11'                                      # back to work
