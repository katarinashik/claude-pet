# storyboard frames for the weather looks, two frames each: snow, wind, clouds, heat, storm
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false
Set-Weather 'snow' 0; Shot 'w1'
Set-Weather 'snow' 1; Set-Eyes 0 2 $false; Shot 'w2'                       # looks up at the flakes
Set-Weather 'wind' 0; Set-Eyes 0 4 $false; Shot 'w3'
Set-Weather 'wind' 1; Set-Eyes 1 3 $false; Shot 'w4'                       # follows a leaf
Set-Weather 'cloud' 0; Set-Eyes 0 4 $false; Shot 'w5'
Set-Weather 'cloud' 2; Set-Eyes 0 2 $false; Shot 'w6'                      # the cloud drifts, he looks up
Set-Weather 'heat' 0; Set-Shades $true 0 0; Show-Eyes $false; Shot 'w7'    # hot: sunglasses, sun, a drop of sweat
Set-Weather 'heat' 1; Shot 'w8'
Set-Shades $false 0 0; Show-Eyes $true; Set-Weather 'storm' 0; Set-Rain 1 0; Set-Eyes 0 2 $false; Shot 'w9'   # storm: dark cloud, rain (the umbrella comes with the rain pose)
Set-Weather 'storm' 1; Set-Rain 1 1; $bang.Visibility = 'Visible'; Shot 'w10'                                                                             # flash!
