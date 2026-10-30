# storyboard frames for the music pose: each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'm1'                              # typing
Set-Laptop 2; Set-Eyes 0 3 $false; Shot 'm2'                                             # puts the laptop away
Set-Laptop 0; Set-Phones $true -3; Set-Eyes 0 2 $false; Shot 'm3'                        # headphones coming down
Set-Phones $true 0; Set-MusicEyes $true; Set-Notes 1; Set-Legs 0; Shot 'm4'             # dancing, eyes closed
$bob.Y = $PX; Set-Legs -1; Set-Notes 2; Shot 'm5'
$bob.Y = 0; Set-Legs 1; Set-Notes 3; Shot 'm6'
$bob.Y = 0; Set-Legs -1; Set-Notes 0; Set-MusicEyes $false; Set-CupLift $true; Set-Eyes 1 2 $false; Shot 'm7'   # hover: lifts a cup, looks at you
Set-CupLift $false; Set-Phones $true -3; Set-Eyes 0 3 $false; Set-Laptop 2; Shot 'm8'   # headphones off, laptop comes back
