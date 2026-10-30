# storyboard frames for the cloudy scene (some clouds): each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Set-Sky -11; Shot 'c1'   # typing, a cloud comes in from the left
Set-Sky -6; Set-Eyes -1 2 $false; Shot 'c2'                               # he notices it
Set-Sky 0; Set-Eyes 0 2 $false; Shot 'c3'                                 # right above him now, he looks up
Set-Sky 0; Set-Eyes 0 4 $false; Shot 'c4'                                 # it stays a while, he types under it
Set-Sky 6; Set-Eyes 1 2 $false; Shot 'c5'                                 # drifts on to the right, he follows it
Set-Sky 99; Set-Eyes 0 4 $false; Shot 'c6'                                # gone, back to work
