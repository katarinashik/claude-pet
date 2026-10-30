# storyboard frames for the heat scene (25 degrees or more): each Shot is one frame
# Set-Heat sunOn frame sweating fanDx spinning ice dripping
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Set-Heat $true 0 $false 99 $false 0 $false; Shot 'h1'   # typing, the sun comes out
Set-Heat $true 1 $true 99 $false 0 $false; Set-Eyes 0 2 $false; Shot 'h2'                                # hot... a drop of sweat
Set-ArmUp $true; Set-Eyes 0 3 $true; Shot 'h3'                                                            # wipes his forehead
Set-ArmUp $false; Set-Heat $true 0 $true 4 $false 0 $false; Set-Eyes 1 4 $false; Shot 'h4'               # pulls a fan in
Set-Heat $true 1 $true 0 $true 0 $false; Set-Eyes 1 3 $false; Shot 'h5'                                   # fan on: wind, his ear flaps
Set-Heat $true 0 $false 0 $true 0 $false; Set-Shades $true 0 0; Show-Eyes $false; Shot 'h6'               # sunglasses on, better
Set-Heat $true 1 $false 0 $true 1 $false; Shot 'h7'                                                       # an ice cream
Set-Heat $true 0 $false 0 $true 2 $true; $tongue.Visibility = 'Visible'; Shot 'h8'                        # licks it, a drip falls
$tongue.Visibility = 'Hidden'; Set-Heat $true 1 $false 0 $true 0 $false; Set-Heart $true; Shot 'h9'      # all gone, ahh
# the heat is over
Set-Heart $false; Set-Heat $false 0 $false 0 $false 0 $false; Shot 'h10'                                   # the sun goes, the fan stops
Set-Shades $false 0 0; Show-Eyes $true; Set-Eyes 0 3 $false; Set-Heat $false 0 $false 3 $false 0 $false; Shot 'h11'   # glasses off, fan slides away
Set-Heat $false 0 $false 99 $false 0 $false; Set-Eyes 0 4 $false; Shot 'h12'                             # back to work
