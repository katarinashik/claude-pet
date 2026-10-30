# storyboard frames for the newspaper pose (a watched job is running): each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'n1'                       # typing
$bang.Visibility = 'Visible'; Set-Eyes 0 2 $false; Shot 'n2'                     # "!" the new issue is out
$bang.Visibility = 'Hidden'; $S.lv = 2; Set-Laptop 2; Set-Legs -1; Shot 'n3'      # closes the laptop
$S.lv = 0; Set-Laptop 0; Set-LaptopAside $true; Set-Eyes -1 4 $false; Shot 'n4'  # and puts it down beside him
Set-Paper $true 3; Set-Eyes 0 3 $false; Shot 'n5'                                # the paper comes up
Set-Paper $true 0; Set-Eyes -1 3 $false; Shot 'n6'                               # reads the left page
Set-Eyes 1 3 $false; Shot 'n7'                                                   # and the right one
Set-Tick $true; Set-Happy $true; Shot 'n8'                                       # all good: a green tick
Set-Paper $false 0; Set-Tick $false; Set-Happy $false; Set-Eyes 0 3 $false; Shot 'n9'   # folds it away
Set-LaptopAside $false; $S.lv = 4; Set-Laptop 4; Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'n10'   # laptop back up, back to work
