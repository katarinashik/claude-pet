# storyboard frames for the rain scene (rain): each Shot is one frame
# Set-RainPuddle size ring jump;  Set-RainUmb 0 none / 1 closed / 2 half / 3 open;  Set-Rain 0 / 1 all over / 2 around the umbrella
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Set-Rain 1 0; Shot 'r1'                              # typing, it starts to rain
Set-Rain 1 1; Set-Splash $true; Set-Eyes 0 2 $false; $bang.Visibility = 'Visible'; Shot 'r2'          # plop, on his head!
$bang.Visibility = 'Hidden'; Set-Splash $false; Set-Rain 1 0; Set-RainUmb 1; Shot 'r3'                 # out comes the umbrella
Set-Rain 1 1; Set-RainUmb 2; Shot 'r4'                                                                 # it opens...
Set-Rain 2 0; Set-RainUmb 3; Set-RainPuddle 1 1 $false; Set-Eyes 0 3 $false; Shot 'r5'                 # ...dry under it; a puddle starts at his feet
Set-Rain 2 1; Set-RainPuddle 2 2 $false; Set-Eyes 1 5 $false; Shot 'r6'                                # it grows, rings from the drops, he eyes it
Set-Rain 2 0; Set-RainPuddle 2 1 $false; Set-Happy $true; Shot 'r7'                                    # cosy, the rain drums on top
# the rain stops
Set-Happy $false; Set-Rain 0 0; Set-RainUmb 2; Set-RainPuddle 2 0 $false; Set-Eyes 0 2 $false; Shot 'r8'   # no more rain, the umbrella folds
Set-RainUmb 1; Set-SnowEnd 1 0; Set-Eyes -1 3 $true; Shot 'r9'                                          # shakes the drops off it
Set-SnowEnd 0 0; Set-RainUmb 0; Set-Raincoat $false 99 99 $true; Set-Eyes 1 5 $false; Shot 'r10'        # umbrella away, boots on, eyes on the puddle...
Set-RainPuddle 2 0 $true; Set-Happy $true; Shot 'r11'                                                    # ...jump! splash
Set-RainPuddle 1 0 $false; Shot 'r12'                                                                    # lands, a smaller puddle, very happy
Set-Happy $false; Set-Raincoat $false 99 99 $false; Set-RainPuddle 0 0 $false; Set-Eyes 0 4 $false; Shot 'r13'   # boots off, puddle gone, back to work
