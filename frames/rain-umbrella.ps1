# storyboard frames for the big umbrella (after 5 min of rain): he carries it off the right edge, plants it out of sight and
# comes back under the left half of its canopy; when the rain stops he goes and takes it down. Each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Set-Rain 1 0; Shot 'p1'                         # 5 min of rain on him and the laptop
Set-Rain 1 1; Set-Eyes 0 2 $false; $bang.Visibility = 'Visible'; Shot 'p2'                       # enough!
$bang.Visibility = 'Hidden'; Set-Rain 1 0; Set-Away 0 $true; Set-Eyes 1 4 $false; Shot 'p3'      # the big umbrella, off to the right
Set-Rain 1 1; Set-Away 6 $true; Set-Legs 1; $bob.Y = $PX; Shot 'p4'
Set-Rain 1 0; Set-Away 14 $true; Set-Legs 0; $bob.Y = 0; Shot 'p5'                               # past the edge
Set-Rain 1 1; Set-Away 24 $false; Set-Legs -1; Shot 'p6'                                         # gone, the laptop alone in the rain
Set-Rain 0 0; Set-BigUmb $true; Show-All $bigRainA $true; Shot 'p7'                              # the canopy opens in from the side
Show-All $bigRainA $false; Show-All $bigRainB $true; Set-Eyes -1 4 $false; Set-Away 12 $false; Set-Legs 1; $bob.Y = $PX; Shot 'p8'   # back, hands empty
Show-All $bigRainB $false; Show-All $bigRainA $true; Set-Away 4 $false; Set-Legs 0; $bob.Y = 0; Shot 'p9'
Show-All $bigRainA $false; Show-All $bigRainB $true; Set-Away 0 $false; Set-Legs -1; Set-Happy $true; Shot 'p10'   # at the laptop, dry
Show-All $bigRainB $false; Show-All $bigRainA $true; Set-Happy $false; Set-Eyes 0 4 $false; Shot 'p11'           # types under it
Show-All $bigRainA $false; Show-All $bigRainB $true; Set-Eyes 0 2 $false; Shot 'p12'                             # the rain drums on top
# the rain stops
Show-All $bigRainB $false; Set-Eyes 1 2 $false; Shot 'p13'                                       # no more rain: a look up
Set-Eyes 1 4 $false; Set-Away 14 $false; Set-Legs 0; Shot 'p14'                                 # goes to take it down
Set-BigUmb $false; Set-Away 24 $false; Set-Legs -1; Shot 'p15'                                   # canopy gone
Set-Eyes -1 4 $false; Set-Away 6 $false; Set-Legs 1; $bob.Y = $PX; Shot 'p16'                   # back
Set-Away 0 $false; Set-Legs -1; $bob.Y = 0; Set-Eyes 0 4 $false; Shot 'p17'                      # at work
