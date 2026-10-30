# storyboard frames for the lunch pose, the morning croissant: each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 'l1'                    # typing
Set-Lunch $true 0 0; Set-Eyes 0 5 $false; Shot 'l2'                             # a croissant! looks at it
Set-Lunch $true 0 -2; Set-Happy $true; Shot 'l3'                                # first bite
Set-Lunch $true 1 0; Set-Crumbs 1; Shot 'l4'                                    # chewing, crumbs fall
Set-Lunch $true 1 -2; Set-Crumbs 2; Shot 'l5'                                   # second bite, crumbs on the laptop
Set-Lunch $true 2 0; Set-Crumbs 1; Shot 'l6'                                    # the last little end
Set-Lunch $false 3 0; Set-Crumbs 2; Set-Heart $true; Shot 'l7'                  # all gone, a little heart
Set-Heart $false; Set-Happy $false; Set-Eyes 0 4 $false; Set-Crumbs 2; Shot 'l8'   # back to work, crumbs stay a while
