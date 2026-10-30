# storyboard frames for the hello (the Claude Pet button on the desktop): he walks in from the right edge of the screen
# with the laptop under his arm, waves hi, puts it down and opens it. Each Shot is one frame
$go = New-Object System.Windows.Media.TranslateTransform; $scene.RenderTransform = $go
$S.lv = 0; Set-Laptop 0; Set-LaptopTuck $true; Set-Eyes -1 3 $false; Set-Legs 0; $bob.Y = $PX; $go.X = 18 * $PX; Shot 'h1'   # peeks in from the edge
Set-Legs 1; $bob.Y = 0; $go.X = 11 * $PX; Shot 'h2'                                      # walks in
Set-Legs 0; $bob.Y = $PX; $go.X = 4 * $PX; Shot 'h3'
Set-Legs -1; $bob.Y = 0; $go.X = 0; Set-Eyes -1 2 $false; Shot 'h4'                      # stops, looks at you
Set-Happy $true; Set-ArmUp $true; Shot 'h5'                                              # hi!
Set-ArmUp $false; Shot 'h6'
Set-ArmUp $true; Shot 'h7'
Set-ArmUp $false; Set-Happy $false; Set-LaptopTuck $false; $S.lv = 1; Set-Laptop 1; Set-Eyes 0 3 $false; Shot 'h8'   # puts it down
$S.lv = 3; Set-Laptop 3; Shot 'h9'                                                       # opens the lid
$S.lv = 4; Set-Laptop 4; Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'h10'    # back to work
