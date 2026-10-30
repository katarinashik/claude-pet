# storyboard frames for the nap pose: each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'n1'                     # typing
Set-Eyes 0 4 $true; Set-Laptop 2; Shot 'n2'                                    # sleepy, laptop going away
Set-Laptop 0; Set-Nap $true; Set-NapEyes 0; Set-Book $true -4; Set-Zz 0; Shot 'n3'   # lies down, book coming down
Set-Book $true 0; Set-Zz 1; Shot 'n4'                                           # asleep
Set-Breath 1; Set-Zz 2; Shot 'n5'                                               # breathes out
Set-Breath 0; Set-Zz 3; Shot 'n6'
Set-Zz 0; Set-Book $true -2; Set-NapEyes 1; $bang.Visibility = 'Visible'; Shot 'n7'   # hover: peeks out
$bang.Visibility = 'Hidden'; Set-Book $false 0; Set-NapEyes 2; Shot 'n8'           # wakes up, book gone
