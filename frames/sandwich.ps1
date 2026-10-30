# storyboard frames for the lunch pose, the sandwich at half past twelve: each Shot is one frame
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Shot 's1'                    # typing
Set-Lunch $true 0 0 'sandwich'; Set-Eyes 0 5 $false; Shot 's2'                             # a sandwich! looks at it
Set-Lunch $true 0 -2 'sandwich'; Set-Happy $true; Shot 's3'                                # first bite
Set-Lunch $true 1 0 'sandwich'; Set-Crumbs 1; Shot 's4'                                    # chewing, crumbs fall
Set-Lunch $true 1 -2 'sandwich'; Set-Crumbs 2; Shot 's5'                                   # second bite, crumbs on the laptop
Set-Lunch $true 2 0 'sandwich'; Set-Crumbs 1; Shot 's6'                                    # the last little end
Set-Lunch $false 3 0 'sandwich'; Set-Crumbs 2; Set-Heart $true; Shot 's7'                  # all gone, a little heart
Set-Heart $false; Set-Happy $false; Set-Eyes 0 4 $false; Set-Crumbs 2; Shot 's8'   # back to work, crumbs stay a while
