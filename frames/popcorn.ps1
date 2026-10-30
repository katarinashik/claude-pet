# storyboard frames for the popcorn pose (Claude Code works on a long task): each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'p1'                 # typing, Claude Code has been busy a while
Set-Popcorn $true 1 -3; Set-Eyes -1 4 $false; Shot 'p2'                    # the bucket comes out
Set-Popcorn $true 1 0; Shot 'p3'                                           # on the lid, hand in the bucket
Set-Popcorn $true 2 0; Set-Happy $true; Shot 'p4'                          # a piece, mmm
Set-Popcorn $true 0 0; Set-Happy $false; Set-Eyes 0 4 $false; Shot 'p5'    # watches the screen
Set-Popcorn $true 1 0; Set-Eyes -1 4 $false; Shot 'p6'                     # another one
Set-Popcorn $true 2 0; Set-Happy $true; Shot 'p7'                          # mmm
Set-Popcorn $false 0 0; Set-Happy $false; Set-Eyes 0 4 $false; Shot 'p8'   # Claude Code is done: bucket away
