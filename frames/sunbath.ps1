# storyboard frames for the sunbath pose: each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 's1'                 # typing
Set-Laptop 0; Set-Eyes 0 2 $false; Set-SunProps $true -8 20 $false; Shot 's2'   # laptop away
Set-SunProps $true -3 20 $false; Shot 's3'                                  # pulls out the deck chair
Set-SunProps $true 0 8 $false; Shot 's4'                                    # plants the umbrella
Set-SunProps $true 0 0 $true; Shot 's5'                                     # opens it
Set-SunBody $true 0 $false; Shot 's6'                                       # lies down: sunglasses, cocktail
Set-SunBody $true 1 $false; Shot 's7'                                       # a sip
Set-SunBody $true 0 $true; Set-SunHeart $true; Shot 's8'                    # hover: peeks over the glasses, a heart
