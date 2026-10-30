# storyboard frames for the snow scene (snowing): each Shot is one frame
# Set-Snow falling frame hatDy scarf pile tongue snowman building
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Set-Snow $true 0 99 $false 0 $false 0 $false; Shot 's1'   # typing, the first flakes
Set-Snow $true 1 99 $false 0 $false 0 $false; Set-Eyes 0 2 $false; $bang.Visibility = 'Visible'; Shot 's2'   # snow!
$bang.Visibility = 'Hidden'; Set-Snow $true 0 -4 $false 0 $false 0 $false; Shot 's3'                        # the hat comes down
Set-Snow $true 1 0 $true 0 $false 0 $false; Set-Happy $true; Shot 's4'                                        # hat and scarf on, cosy
Set-Happy $false; Set-Eyes 0 4 $false; Set-Snow $true 0 0 $true 1 $false 0 $false; Shot 's5'                  # types on, snow piles up on the lid and the ears
Set-Eyes 0 2 $false; Set-Snow $true 1 0 $true 1 $true 0 $false; Shot 's6'                                    # catches a flake on his tongue
Set-Eyes 1 4 $false; Set-Snow $true 0 0 $true 2 $false 1 $true; Shot 's7'                                     # starts a snowman beside him
Set-Snow $true 1 0 $true 2 $false 2 $true; Shot 's8'                                                          # the head goes on
Set-Snow $true 0 0 $true 2 $false 3 $false; Set-Happy $true; Set-Heart $true; Shot 's9'                       # eyes and a carrot nose: done!
Set-Heart $false; Set-Happy $false; Set-Eyes 0 4 $false; Set-Snow $true 1 0 $true 2 $false 3 $false; Shot 's10'  # back to work next to his snowman
# the snow stops
Set-Snow $false 0 0 $true 2 $false 3 $false; Set-Eyes 0 2 $false; Shot 's11'                                  # no more flakes, he looks up
Set-Snow $false 0 0 $true 1 $false 3 $false; Set-SnowEnd 1 0; Set-Eyes -1 3 $true; Shot 's12'                 # shakes the snow off, left...
Set-Snow $false 0 0 $true 0 $false 3 $false; Set-SnowEnd 2 0; Set-Eyes 1 3 $true; Shot 's13'                  # ...and right, the lid is clean
Set-SnowEnd 0 0; Set-ArmUp $true; Set-Snow $false 0 -3 $true 0 $false 3 $false; Set-Eyes 0 3 $false; Shot 's14'   # lifts the hat off
Set-ArmUp $false; Set-Snow $false 0 99 $false 0 $false 0 $false; Set-SnowEnd 0 1; Set-Eyes 1 4 $false; Shot 's15'   # hat and scarf off; the snowman starts to melt
Set-SnowEnd 0 2; Shot 's16'                                                                                   # melts some more
Set-SnowEnd 0 3; Set-Eyes 0 4 $false; Shot 's17'                                                              # only a puddle, back to work
