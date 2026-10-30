# storyboard frames for the bug hunt pose: each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Set-Bug $true -3 0; Shot 'b1'           # typing, a bug comes up on the lid
Set-Bug $true 0 1; Set-Eyes -1 4 $false; Shot 'b2'                                        # crawls along, he looks at it
Set-Bug $true 2 0; $bang.Visibility = 'Visible'; Shot 'b3'                                 # "!" a bug!
$bang.Visibility = 'Hidden'; Set-Bug $true 4 1; Set-Jar 'down' -4; Shot 'b4'               # the jar comes up over it
Set-Jar 'down' 0; Shot 'b5'                                                               # slam: caught
Set-Bug $false 0 0; Set-Jar 'up' 0; Set-Eyes 0 3 $false; Shot 'b6'                         # lifts the jar and looks up at it
Set-Tick $true; Set-Happy $true; Shot 'b7'                                                 # fixed!
Set-Tick $false; Set-Happy $false; Set-Jar '' 0; Set-Eyes 0 4 $false; Shot 'b8'            # back to work
