# storyboard frames for the goodbye ("Bye, Claude" in the menu): he closes the lid, waves at you, takes the laptop under
# his arm and walks off the right edge of the screen. Each Shot is one frame. $go slides the whole pet the way the window will move
$go = New-Object System.Windows.Media.TranslateTransform; $scene.RenderTransform = $go
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'b1'                              # typing
$S.lv = 2; Set-Laptop 2; Set-Eyes 0 3 $false; Shot 'b2'                                  # the lid comes down
$S.lv = 1; Set-Laptop 1; Shot 'b3'                                                       # closed
Set-Eyes -1 2 $false; Set-ArmUp $true; Shot 'b4'                                         # looks at you, hand up
Set-Happy $true; Set-ArmUp $false; Shot 'b5'                                             # waves: down
Set-ArmUp $true; Shot 'b6'                                                               # and up: bye!
Set-ArmUp $false; Set-Happy $false; $S.lv = 0; Set-Laptop 0; Set-LaptopTuck $true; Set-Eyes 0 3 $false; Shot 'b7'   # takes it under his arm
$flip.ScaleX = -1; Set-Eyes 1 3 $false; Set-Legs 0; $bob.Y = $PX; $go.X = 4 * $PX; Shot 'b8'   # turns and walks off
Set-Legs 1; $bob.Y = 0; $go.X = 11 * $PX; Shot 'b9'
Set-Legs 0; $bob.Y = $PX; $go.X = 18 * $PX; Shot 'b10'                                  # past the edge
$go.X = 26 * $PX; Shot 'b11'                                                             # gone
