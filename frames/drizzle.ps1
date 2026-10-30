# storyboard frames for the drizzle scene (light rain): each Shot is one frame
# Set-Drizzle falling frame faceSplash beads puddle;  Set-Raincoat bundle coatDy hoodDy boots
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Set-Drizzle $true 0 $false $false $false; Shot 'd1'   # typing, fine drizzle starts
Set-Drizzle $true 1 $true $false $false; Set-Eyes 0 4 $true; Shot 'd2'                                # plip, right on his face, he blinks
Set-Drizzle $true 0 $false $false $false; Set-Raincoat $true 99 99 $false; Set-Eyes 1 4 $false; Shot 'd3'   # gets his yellow raincoat out
Set-Drizzle $true 1 $false $false $false; Set-Raincoat $false 3 99 $false; Set-Eyes 0 4 $false; Shot 'd4'   # pulls the coat on...
Set-Drizzle $true 0 $false $false $false; Set-Raincoat $false 0 99 $true; Set-Eyes 0 5 $false; Shot 'd5'    # ...on, and the boots
Set-Drizzle $true 1 $false $false $false; Set-Raincoat $false 0 -3 $true; Set-Eyes 0 2 $false; Shot 'd6'    # the hood goes up...
Set-Drizzle $true 0 $false $false $false; Set-Raincoat $false 0 0 $true; Set-Happy $true; Shot 'd7'         # ...all set, snug
Set-Happy $false; Set-Eyes 0 4 $false; Set-Drizzle $true 1 $false $true $true; Shot 'd8'                     # types on, drops on the hood, a puddle at his feet
# the drizzle stops
Set-Drizzle $false 0 $false $true $true; Set-Eyes 0 2 $false; Shot 'd9'                                     # no more drops, he looks up
Set-Drizzle $false 0 $false $false $true; Set-Raincoat $false 0 -3 $true; Set-SnowEnd 1 0; Set-Eyes -1 3 $true; Shot 'd10'   # hood back, shakes the water off
Set-SnowEnd 2 0; Set-Raincoat $false 3 99 $true; Set-Eyes 1 3 $true; Shot 'd11'                             # the coat comes off
Set-SnowEnd 0 0; Set-Raincoat $false 99 99 $false; Set-Drizzle $false 0 $false $false $false; Set-Eyes 0 4 $false; Shot 'd12'   # boots off, the puddle dries, back to work
