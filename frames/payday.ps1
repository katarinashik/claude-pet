# storyboard frames for the payday pose: each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'p1'                  # typing
Set-Wallet $true 2; Set-Eyes 0 5 $false; Shot 'p2'                           # wallet out, looks at it
Set-Wallet $true 1; Shot 'p3'                                                # the bill slides up
Set-Wallet $true 0; Set-Happy $true; Set-PaySpark 1; Shot 'p4'               # payday! happy eyes
Set-PaySpark 2; Shot 'p5'
Set-PaySpark 1; Shot 'p6'
Set-Wallet $true -2; Set-PaySpark 3; Shot 'p7'                               # hover: pulls the bill up to show you
Set-Happy $false; Set-PaySpark 0; Set-Wallet $false 2; Set-Eyes 0 4 $false; Shot 'p8'   # back to work
